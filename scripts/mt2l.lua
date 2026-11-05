-- Typst contracts remain transparent during normal compilation. This filter
-- discovers local modules and transforms calls before using Pandoc's reader.
local script_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local lex = dofile(pandoc.path.join({ script_dir, "mt2l", "lexer.lua" }))
local trim, balanced, skip_space = lex.trim, lex.balanced, lex.skip_space
local function absolute(path)
  if not pandoc.path.is_absolute(path) then
    path = pandoc.path.join({ pandoc.system.get_working_directory(), path })
  end
  return pandoc.path.normalize(path)
end
local source_path = absolute(assert(PANDOC_STATE.input_files[1], "mt2l needs an input file"))
local project_root = absolute(os.getenv("MT2L_PROJECT_ROOT") or ".")
local latex_asset_dir = os.getenv("MT2L_LATEX_ASSET_DIR") or os.getenv("MT2L_ASSET_DIR") or "mt2l-assets"
local asset_dir = absolute(os.getenv("MT2L_ASSET_DIR") or "mt2l-assets")

local function read_file(path)
  local file, message = io.open(path, "r")
  assert(file, message)
  local source = file:read("*a")
  file:close()
  return source
end
local source = read_file(source_path)
local engine_version = assert(("\n" .. read_file(pandoc.path.join({ script_dir, "..", "typst.toml" })))
  :match('\nversion%s*=%s*"([^"]+)"'), "missing mt2l engine version")

local function diagnostic(path, text, offset, message)
  local before = text:sub(1, offset - 1)
  local _, lines = before:gsub("\n", "")
  local column = #before - (before:match(".*()\n") or 0) + 1
  message = tostring(message):gsub("^.-%.lua:%d+: ", "")
  error(path .. ":" .. (lines + 1) .. ":" .. column .. ": " .. message, 0)
end

local function unquote(value)
  value = trim(value)
  if value:sub(1, 1) ~= '"' or value:sub(-1) ~= '"' then return value end
  local out, i = {}, 2
  local escapes = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ['\\'] = '\\' }
  while i < #value do
    local char = value:sub(i, i)
    if char ~= "\\" then out[#out + 1], i = char, i + 1
    else
      local code = value:sub(i + 1, i + 1)
      if code == "u" then
        local digits, finish = value:match("^u{(%x+)}()", i + 1)
        assert(digits, "invalid Unicode string escape")
        out[#out + 1], i = utf8.char(tonumber(digits, 16)), finish
      else
        assert(escapes[code], "unsupported string escape: \\" .. code)
        out[#out + 1], i = escapes[code], i + 2
      end
    end
  end
  return table.concat(out)
end

local function arguments(s)
  local named, positional = {}, {}
  for _, part in ipairs(lex.split(s)) do
    if part ~= "" then
      local key, value = part:match("^([%w_%-]+)%s*:%s*(.*)$")
      if key then
        assert(named[key] == nil, "duplicate argument: " .. key)
        named[key] = trim(value)
      else positional[#positional + 1] = part end
    end
  end
  return named, positional
end

local function raw_block(value)
  value = trim(value or "")
  if value == "" then return "" end
  local fence = value:match("^(```+)")
  assert(fence, "templates and preambles must be fenced raw blocks")
  local newline = assert(value:find("\n", #fence + 1, true), "raw template needs a newline")
  local finish = #value - #fence + 1
  assert(value:sub(finish) == fence, "unterminated raw template")
  return value:sub(newline + 1, finish - 1):gsub("\n$", "")
end

local function is_array(value)
  if type(value) ~= "table" then return false end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" then return false end
    count = count + 1
  end
  return count == #value
end

local function meta_value(value)
  if type(value) == "boolean" then return pandoc.MetaBool(value) end
  if type(value) == "number" or type(value) == "string" then return pandoc.MetaString(tostring(value)) end
  if is_array(value) then
    local values = pandoc.List:new()
    for _, item in ipairs(value) do values:insert(meta_value(item)) end
    return pandoc.MetaList(values)
  end
  if type(value) == "table" then
    local values = {}
    for key, item in pairs(value) do values[key] = meta_value(item) end
    return pandoc.MetaMap(values)
  end
  error("unsupported mt2l metadata value: " .. type(value), 0)
end

-- Typst resolves contextual global metadata in the original, complete document.
local global_values, global_meta = {}, {}
do
  local json = pandoc.pipe("typst", {
    "eval", "query(<mt2l-meta>)", "--root", project_root, "--in", source_path,
  }, "")
  local entries = pandoc.json.decode(json)
  assert(#entries <= 1, "mt2l-meta may be exported at most once")
  if #entries == 1 then
    assert(type(entries[1].value) == "table", "mt2l-meta must evaluate to a dictionary")
    global_values = entries[1].value
    for key, value in pairs(global_values) do global_meta[key] = meta_value(value) end
  end
end

-- Discover contracts through local imports without executing package sources in
-- Pandoc. Each module has its own namespace; aliases never leak between modules.
local modules, loading = {}, {}
local load_module
local function import_path(path, origin)
  if path:sub(1, 1) == "/" then path = project_root .. path
  else path = pandoc.path.join({ pandoc.path.directory(origin), path }) end
  path = pandoc.path.normalize(path)
  local root = pandoc.path.normalize(project_root)
  local prefix = root == "/" and "/" or root .. "/"
  assert(path == root or path:sub(1, #prefix) == prefix, "import outside project root: " .. path)
  return path
end

load_module = function(path)
  if modules[path] then return modules[path] end
  assert(not loading[path], "cyclic local import: " .. path)
  loading[path] = true
  local text, scope, spans, declarations, exports = read_file(path), {}, {}, {}, {}
  local imports, metadata_calls, metadata_names = {}, {}, {}
  lex.hashes(text, function(i)
    local tail = text:sub(i)
    if tail:match("^#import%f[^%w_%-]") then
      local finish = lex.statement_end(text, i)
      imports[#imports + 1] = { i, finish }
      spans[#spans + 1] = { i, finish }
      return finish + 1
    end
    local name, after_name = tail:match("^#let%s+([%w_%-]+)()")
    if name then
      local value = skip_space(text, i + after_name - 1)
      if text:sub(value, value) == "=" then
        value = skip_space(text, value + 1)
        local finish = lex.statement_end(text, i)
        declarations[name] = { i, finish }
        if text:sub(value):match("^mt2l%s*%(") then
          local paren = assert(text:find("(", value, true))
          local close = balanced(text, paren)
          local ok, contract = pcall(function()
            local args, positional = arguments(text:sub(paren + 1, close - 1))
            assert(#positional == 0, "contract options must be named")
            local allowed = {
              fn = true, mode = true, placement = true, ["latex-template"] = true,
              ["typst-template"] = true, ["typst-preamble"] = true, ["latex-preamble"] = true,
            }
            for key in pairs(args) do assert(allowed[key], "unknown contract option: " .. key) end
            assert(args.fn, "contract needs fn: ...")
            assert(args["latex-template"], "contract needs latex-template")
            local mode, placement = unquote(args.mode or '"syntax"'), unquote(args.placement or '"auto"')
            assert(mode == "syntax" or mode == "pdfrender", "unknown mode: " .. mode)
            assert(placement == "auto" or placement == "inline" or placement == "block", "unknown placement: " .. placement)
            assert(mode ~= "pdfrender" or args["typst-template"], "pdfrender needs typst-template")
            return {
              alias = name, fn = args.fn, mode = mode, placement = placement,
              latex_template = raw_block(args["latex-template"]),
              typst_template = raw_block(args["typst-template"]),
              typst_preamble = raw_block(args["typst-preamble"]),
              latex_preamble = raw_block(args["latex-preamble"]),
              directory = pandoc.path.directory(path),
            }
          end)
          if not ok then
            diagnostic(path, text, i, "contract " .. name .. ": " .. tostring(contract):gsub("^.-%.lua:%d+: ", ""))
          end
          exports[name] = contract
          spans[#spans + 1] = { i, close }
          return close + 1
        end
        return finish + 1
      elseif name == "mt2l" then
        -- Also permit the prelude to be defined directly in a source document.
        local finish = lex.statement_end(text, i)
        spans[#spans + 1] = { i, finish }
        return finish + 1
      end
    end
    if tail:match("^#mt2l%-export%-meta%f[^%w_%-]") then
      local paren = skip_space(text, i + #"#mt2l-export-meta")
      local close = balanced(text, paren)
      metadata_calls[#metadata_calls + 1] = { i, close }
      local arg = trim(text:sub(paren + 1, close - 1))
      if arg:match("^[%w_%-]+$") then metadata_names[arg] = true end
      return close + 1
    end
  end)
  for _, span in ipairs(imports) do
    local declaration = lex.without_comments(text:sub(span[1], span[2]))
    local from = skip_space(declaration, #"#import" + 1)
    local ok, message = pcall(function()
      assert(declaration:sub(from, from) == '"', "imports must use literal paths")
      local finish = lex.opaque(declaration, from)
      local target = unquote(declaration:sub(from, finish - 1))
      local package_version = target:match("^@[%w_%-]+/mt2l:(.+)$")
      if package_version then
        -- Patch releases retain the contract API. Keep existing documents
        -- exportable when the CLI is updated within the same minor version.
        assert(package_version:match("^(%d+%.%d+)%.%d+$") == engine_version:match("^(%d+%.%d+)%.%d+$"),
          "mt2l package " .. package_version .. " does not match engine " .. engine_version
            .. "; use the matching mt2l command or update the import")
      end
      if target:sub(1, 1) == "@" then return end
      local imported = load_module(import_path(target, path)).exports
      local suffix = trim(declaration:sub(finish))
      if suffix:sub(1, 1) == ":" then
        suffix = trim(suffix:sub(2))
        if suffix == "*" then
          for alias, contract in pairs(imported) do scope[alias] = contract end
        else
          for _, item in ipairs(lex.split(suffix)) do
            local original, alias = item:match("^([%w_%-]+)%s+as%s+([%w_%-]+)$")
            original = original or item
            if imported[original] then scope[alias or original] = imported[original] end
          end
        end
      else
        local namespace = suffix:match("^as%s+([%w_%-]+)$")
          or pandoc.path.filename(target):gsub("%.typ$", "")
        for alias, contract in pairs(imported) do scope[namespace .. "." .. alias] = contract end
      end
    end)
    if not ok then diagnostic(path, text, span[1], message) end
  end
  -- Named imports are themselves re-exported, as in ordinary Typst modules.
  for alias, contract in pairs(scope) do
    if not exports[alias] then exports[alias] = contract end
  end
  for alias, contract in pairs(exports) do scope[alias] = contract end
  for _, span in ipairs(metadata_calls) do spans[#spans + 1] = span end
  for name in pairs(metadata_names) do
    if declarations[name] then spans[#spans + 1] = declarations[name] end
  end
  local module = { exports = exports, scope = scope, source = lex.remove_spans(text, spans), original = text, path = path }
  modules[path], loading[path] = module, nil
  return module
end

local root_module = load_module(source_path)
local replacements, serial = {}, 0
local prefix = "MT2L" .. pandoc.utils.sha1(source):sub(1, 12) .. "X"
while source:find(prefix, 1, true) do prefix = prefix .. "X" end
local marker_pattern = prefix .. "%d+END"
local transform, latex_from_typst
local preambles, seen_preambles, compiled_templates = {}, {}, {}

local function base_context()
  local context = {}
  for key, value in pairs(global_values) do context[key] = value end
  return context
end

local function apply_template(text, context)
  if not compiled_templates[text] then compiled_templates[text] = pandoc.template.compile(text) end
  return tostring(pandoc.template.apply(compiled_templates[text], context))
end

local function restore(doc)
  -- Convert standalone calls into blocks at every nesting depth, before the
  -- inline walk. A mixed paragraph is never replaced wholesale.
  doc = doc:walk({
    Para = function(el)
      if #el.content == 1 and el.content[1].t == "Str" then
        local replacement = replacements[el.content[1].text]
        if replacement and replacement.placement ~= "inline" then
          return pandoc.RawBlock("latex", replacement.latex)
        end
      end
    end,
    Plain = function(el)
      if #el.content == 1 and el.content[1].t == "Str" then
        local replacement = replacements[el.content[1].text]
        if replacement and replacement.placement ~= "inline" then
          return pandoc.RawBlock("latex", replacement.latex)
        end
      end
    end,
  })
  local function inline_replacement(replacement)
    assert(replacement.placement ~= "block", replacement.location .. ": block contract cannot appear inside text or math")
    return replacement.latex
  end
  return doc:walk({
    Math = function(el)
      el.text = el.text:gsub(marker_pattern, function(marker)
        local replacement = replacements[marker]
        return replacement and inline_replacement(replacement) or marker
      end)
      -- Keeping Math preserves DisplayMath/InlineMath and Pandoc's delimiters.
      return el
    end,
    Str = function(el)
      local out, start = {}, 1
      while true do
        local first, last = el.text:find(marker_pattern, start)
        if not first then break end
        if first > start then out[#out + 1] = pandoc.Str(el.text:sub(start, first - 1)) end
        local marker = el.text:sub(first, last)
        local replacement = replacements[marker]
        out[#out + 1] = replacement and pandoc.RawInline("latex", inline_replacement(replacement)) or pandoc.Str(marker)
        start = last + 1
      end
      if start == 1 then return nil end
      if start <= #el.text then out[#out + 1] = pandoc.Str(el.text:sub(start)) end
      return out
    end,
  })
end

latex_from_typst = function(text, scope, preamble)
  local converted = transform(text, scope)
  local doc = pandoc.read((preamble or "") .. "\n" .. converted, "typst")
  return trim(pandoc.write(restore(doc), "latex"))
end

local function latex_argument(value, scope, preamble)
  value = trim(value or "")
  if value == "true" then return true end
  if value == "false" or value == "none" then return false end
  if value:sub(1, 1) == "[" and balanced(value, 1) == #value then
    return latex_from_typst(value:sub(2, -2), scope, preamble)
  end
  if value:sub(1, 1) == '"' and value:sub(-1) == '"' then
    return trim(pandoc.write(pandoc.Pandoc({ pandoc.Plain({ pandoc.Str(unquote(value)) }) }), "latex"))
  end
  -- A callback is source code, available to templates through RAW. It has no
  -- meaningful prose representation and must not be evaluated by Pandoc.
  if value:sub(1, 1) == "{" then return value end
  return latex_from_typst(value, scope, preamble)
end

local function conversion_arguments(args_source)
  local named, positional = arguments(args_source)
  local locals = {}
  if named.mt2l_variables then
    local raw = named.mt2l_variables
    assert(raw:sub(1, 1) == "(" and balanced(raw, 1) == #raw, "mt2l_variables must be a literal named dictionary")
    local extra
    locals, extra = arguments(raw:sub(2, -2))
    assert(#extra == 0, "mt2l_variables accepts named values only")
    named.mt2l_variables = nil
  end
  return named, positional, locals
end

local function context_for(contract, args_source, body_source, scope, raw)
  local named, positional, locals = conversion_arguments(args_source)
  local context, args, local_values = base_context(), { pos = {} }, {}
  local raw_values = { ARGS = { pos = {} }, LOCAL = {}, BODY = body_source or "" }
  local function needed(namespace)
    return raw or contract.latex_template:find("[$(]" .. namespace .. "[.$)]") ~= nil
  end
  local function convert(value)
    return raw and value or latex_argument(value, scope, contract.typst_preamble)
  end
  for name, value in pairs(named) do
    if needed("ARGS") then args[name] = convert(value) end
    raw_values.ARGS[name] = unquote(value)
  end
  for _, value in ipairs(positional) do
    if needed("ARGS") then args.pos[#args.pos + 1] = convert(value) end
    raw_values.ARGS.pos[#raw_values.ARGS.pos + 1] = unquote(value)
  end
  for name, value in pairs(locals) do
    if needed("LOCAL") then local_values[name] = convert(value) end
    raw_values.LOCAL[name] = unquote(value)
  end
  context.ARGS, context.LOCAL, context.RAW = args, local_values, raw_values
  if needed("BODY") then
    context.BODY = raw and (body_source or "") or latex_from_typst(body_source or "", scope, contract.typst_preamble)
  end
  context.TARGET = contract.fn
  -- Typst stdin is located at the project root, even when cwd differs. Give
  -- templates an explicit root-relative module path for local resources.
  context.MODULE = project_root == "/" and contract.directory or contract.directory:sub(#project_root + 1)
  return context
end

local function render_contract(contract, args_source, body_source, scope)
  if contract.latex_preamble ~= "" and not seen_preambles[contract.latex_preamble] then
    seen_preambles[contract.latex_preamble] = true
    preambles[#preambles + 1] = contract.latex_preamble
  end
  local path
  if contract.mode == "pdfrender" then
    local kept = {}
    for _, part in ipairs(lex.split(args_source)) do
      if part:match("^([%w_%-]+)%s*:") ~= "mt2l_variables" then kept[#kept + 1] = part end
    end
    local typst_context = context_for(contract, args_source, body_source, scope, true)
    typst_context.HERE = "#" .. contract.fn .. "(" .. table.concat(kept, ", ") .. ")"
    if body_source ~= nil then typst_context.HERE = typst_context.HERE .. "[" .. body_source .. "]" end
    local rendered = contract.typst_preamble .. "\n" .. apply_template(contract.typst_template, typst_context)
    -- Content-based names prevent a failed build from overwriting the assets
    -- referenced by a previous successful .tex file. No dependency-blind cache.
    local hash = pandoc.utils.sha1(contract.directory .. "\n" .. rendered):sub(1, 20)
    local filename = "mt2l-" .. contract.alias:gsub("[^%w%-]", "-") .. "-" .. hash .. ".pdf"
    local typst_path = pandoc.path.join({ asset_dir, (filename:gsub("%.pdf$", ".typ")) })
    local pdf_path = pandoc.path.join({ asset_dir, filename })
    pandoc.system.make_directory(asset_dir, true)
    local file = assert(io.open(typst_path, "w"))
    file:write(rendered)
    file:close()
    -- stdin permits output outside the project without writing temporary files
    -- into an imported module. Resource paths can use $MODULE$ in the template.
    pandoc.system.with_temporary_directory(asset_dir, ".mt2l-", function(directory)
      local temporary_pdf = pandoc.path.join({ directory, "render.pdf" })
      pandoc.pipe("typst", { "compile", "--root", project_root, "-", temporary_pdf }, rendered)
      assert(os.rename(temporary_pdf, pdf_path))
    end)
    path = latex_asset_dir .. "/" .. filename
  end
  local context = context_for(contract, args_source, body_source, scope, false)
  context.PATH = path
  return apply_template(contract.latex_template, context)
end

transform = function(text, scope, origin, original)
  local out, start = {}, 1
  lex.hashes(text, function(i)
    local alias, after = text:sub(i):match("^#([%w_%-]+[%.%w_%-]*)()")
    local contract = alias and scope[alias]
    if not contract then return end
    local ok, finish, rendered = pcall(function()
      local next_pos = skip_space(text, i + after - 1)
      local args_source, close = "", next_pos - 1
      if text:sub(next_pos, next_pos) == "(" then
        close = balanced(text, next_pos)
        args_source = text:sub(next_pos + 1, close - 1)
        next_pos = skip_space(text, close + 1)
      end
      local body_source
      if text:sub(next_pos, next_pos) == "[" then
        close = balanced(text, next_pos)
        body_source = text:sub(next_pos + 1, close - 1)
      end
      assert(close >= i + after - 1, "contract call needs (...) or [...]")
      return close, render_contract(contract, args_source, body_source, scope)
    end)
    if not ok then
      diagnostic(origin or source_path, original or text, i,
        "contract " .. alias .. ": " .. tostring(finish):gsub("^.-%.lua:%d+: ", ""))
    end
    serial = serial + 1
    local marker = prefix .. serial .. "END"
    local before = (original or text):sub(1, i - 1)
    local _, lines = before:gsub("\n", "")
    replacements[marker] = {
      latex = rendered, placement = contract.placement,
      location = (origin or source_path) .. ":" .. (lines + 1) .. " (" .. alias .. ")",
    }
    out[#out + 1] = text:sub(start, i - 1)
    -- An evaluated Typst string works in both markup and math without adding
    -- literal quotation marks to Pandoc's inline representation.
    out[#out + 1] = '#("' .. marker .. '")'
    start = finish + 1
    return start
  end)
  out[#out + 1] = text:sub(start)
  return table.concat(out)
end

function Pandoc(_)
  local converted = transform(root_module.source, root_module.scope, source_path, source)
  local doc = restore(pandoc.read(converted, "typst"))
  for key, value in pairs(global_meta) do doc.meta[key] = value end
  if #preambles > 0 then
    local includes = doc.meta["header-includes"] or pandoc.MetaList({})
    if pandoc.utils.type(includes) ~= "List" then includes = pandoc.MetaList({ includes }) end
    for _, preamble in ipairs(preambles) do includes:insert(pandoc.MetaBlocks({ pandoc.RawBlock("latex", preamble) })) end
    doc.meta["header-includes"] = includes
  end
  return doc
end
