-- Typst contracts remain transparent during normal compilation. This filter
-- discovers local modules and transforms calls before using Pandoc's reader.
local script_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
local lex = dofile(pandoc.path.join({ script_dir, "mt2l", "lexer.lua" }))
local natural = dofile(pandoc.path.join({ script_dir, "mt2l", "natural.lua" }))
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
local converter_root = absolute(pandoc.path.join({ script_dir, ".." }))
local exported_assets = {}

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
  message = tostring(message):gsub("^[^\n]-%.lua:%d+: ", "")
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
local native_targets = {}
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
if global_values["mt2l-paper"] then
  local entries = pandoc.json.decode(pandoc.pipe("typst", {
    "eval", 'query(selector(heading).or(figure).or(math.equation)).filter(el => el.has("label")).map(el => (id: str(el.label), kind: if el.func() == math.equation { "equation" } else { "reference" }))',
    "--root", project_root, "--in", source_path,
  }, ""))
  for _, target in ipairs(entries) do native_targets[target.id] = target.kind end
end

-- Discover contracts through local imports without executing package sources in
-- Pandoc. Each module has its own namespace; aliases never leak between modules.
local modules, loading = {}, {}
local load_module
local function import_path(path, origin, boundary)
  if path:sub(1, 1) == "/" then path = project_root .. path
  else path = pandoc.path.join({ pandoc.path.directory(origin), path }) end
  path = pandoc.path.normalize(path)
  local root = pandoc.path.normalize(boundary or project_root)
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
              ["body-format"] = true, ["asset-argument"] = true,
              ["reference-argument"] = true, ["render-context"] = true,
              ["label-argument"] = true,
            }
            for key in pairs(args) do assert(allowed[key], "unknown contract option: " .. key) end
            assert(args.fn, "contract needs fn: ...")
            assert(args["latex-template"], "contract needs latex-template")
            local mode, placement = unquote(args.mode or '"syntax"'), unquote(args.placement or '"auto"')
            assert(mode == "syntax" or mode == "pdfrender", "unknown mode: " .. mode)
            assert(placement == "auto" or placement == "inline" or placement == "block" or placement == "document", "unknown placement: " .. placement)
            local render_context = unquote(args["render-context"] or '"isolated"')
            assert(render_context == "isolated" or render_context == "document", "unknown render-context: " .. render_context)
            assert(render_context ~= "document" or mode == "pdfrender", "document render-context requires pdfrender")
            assert(mode ~= "pdfrender" or render_context == "document" or args["typst-template"], "isolated pdfrender needs typst-template")
            local body_format = unquote(args["body-format"] or '"latex"')
            assert(body_format == "latex" or body_format == "math", "unknown body-format: " .. body_format)
            assert(not args["asset-argument"] or mode == "syntax", "asset-argument requires syntax mode")
            return {
              alias = name, fn = args.fn, mode = mode, placement = placement,
              latex_template = raw_block(args["latex-template"]),
              typst_template = raw_block(args["typst-template"]),
              typst_preamble = raw_block(args["typst-preamble"]),
              latex_preamble = raw_block(args["latex-preamble"]),
              body_format = body_format,
              asset_argument = args["asset-argument"] and unquote(args["asset-argument"]),
              reference_argument = args["reference-argument"] and unquote(args["reference-argument"]),
              label_argument = args["label-argument"] and unquote(args["label-argument"]),
              render_context = render_context,
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
      if target:sub(1, 1) == "@" and not package_version then return end
      -- The bundled bindings are shared by the CLI and the Typst package.
      -- Other third-party packages still require explicit local adapters.
      local bundled = path == pandoc.path.join({ converter_root, "mt2l.typ" })
        or path == pandoc.path.join({ converter_root, "templates", "paper.typ" })
        or path == pandoc.path.join({ converter_root, "templates", "statements.typ" })
      local imported = load_module(package_version
        and pandoc.path.join({ converter_root, "mt2l.typ" })
        or import_path(target, path, bundled and converter_root or nil)).exports
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
  lex.hashes(text, function(i)
    if text:sub(i):match("^#show%s*:") then
      local finish = lex.statement_end(text, i)
      local expression = trim(text:sub(i, finish):match("^#show%s*:%s*(.*)"))
      local alias = expression:match("^([%w_.%-]+)%.with%s*%(") or expression:match("^([%w_.%-]+)%s*$")
      if alias and scope[alias] and scope[alias].placement == "document" then
        spans[#spans + 1] = { i, finish }
        return finish + 1
      end
    end
  end)
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
  doc = doc:walk({
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
  return global_values["mt2l-paper"] and natural.restore(doc, native_targets) or doc
end

latex_from_typst = function(text, scope, preamble, body_format)
  -- A content block often starts on a new, indented line. Keep relative
  -- indentation (lists/code) while exposing headings to Pandoc's reader.
  local indent
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if line:find("%S") then
      local width = #(line:match("^ *"))
      indent = math.min(indent or width, width)
    end
  end
  if indent and indent > 0 then
    text = ("\n" .. text):gsub("\n" .. string.rep(" ", indent), "\n"):sub(2)
  end
  local converted = transform(text, scope)
  local doc = pandoc.read((preamble or "") .. "\n" .. converted, "typst")
  doc = restore(doc)
  if body_format == "math" then
    assert(#doc.blocks == 1 and (doc.blocks[1].t == "Para" or doc.blocks[1].t == "Plain")
      and #doc.blocks[1].content == 1 and doc.blocks[1].content[1].t == "Math",
      "body-format math needs a single $ ... $ equation")
    return doc.blocks[1].content[1].text
  end
  return trim(pandoc.write(doc, "latex", { cite_method = "natbib" }))
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

local function latex_reference(value)
  if value == "none" or value == "()" then return false end
  local values = { value }
  if value:sub(1, 1) == "(" and balanced(value, 1) == #value then
    values = lex.split(value:sub(2, -2))
  end
  local ids, seen = {}, {}
  for _, item in ipairs(values) do
    local id = item:match("^<([^<>]+)>$")
    if not id and item:sub(1, 1) == '"' and lex.opaque(item, 1) == #item + 1 then id = unquote(item) end
    assert(id and id:match("^[%w_:%.%-]+$"), "reference-argument needs literal IDs or labels, optionally in a tuple")
    if not seen[id] then ids[#ids + 1], seen[id] = id, true end
  end
  return #ids > 0 and ("\\cref{" .. table.concat(ids, ",") .. "}") or false
end

local function context_for(contract, args_source, body_source, scope, raw)
  local named, positional, locals = conversion_arguments(args_source)
  local context, args, local_values = base_context(), { pos = {} }, {}
  local raw_values = { ARGS = { pos = {} }, LOCAL = {}, BODY = body_source or "" }
  local function needed(namespace, field)
    if raw then return true end
    if field then
      local escaped = field:gsub("([^%w_])", "%%%1")
      return contract.latex_template:find("[$(]" .. namespace .. "%." .. escaped .. "[.$)/]") ~= nil
        or contract.latex_template:find("[$(]" .. namespace .. "[$)]") ~= nil
    end
    return contract.latex_template:find("[$(]" .. namespace .. "[.$)]") ~= nil
  end
  local function convert(value)
    return raw and value or latex_argument(value, scope, contract.typst_preamble)
  end
  for name, value in pairs(named) do
    if needed("ARGS", name) then
      if not raw and name == contract.reference_argument then args[name] = latex_reference(value)
      else args[name] = convert(value) end
    end
    raw_values.ARGS[name] = unquote(value)
  end
  for _, value in ipairs(positional) do
    if needed("ARGS", "pos") then args.pos[#args.pos + 1] = convert(value) end
    raw_values.ARGS.pos[#raw_values.ARGS.pos + 1] = unquote(value)
  end
  for name, value in pairs(locals) do
    if needed("LOCAL", name) then local_values[name] = convert(value) end
    raw_values.LOCAL[name] = unquote(value)
  end
  context.ARGS, context.LOCAL, context.RAW = args, local_values, raw_values
  if needed("BODY") then
    context.BODY = raw and (body_source or "") or latex_from_typst(body_source or "", scope, contract.typst_preamble, contract.body_format)
  end
  context.TARGET = contract.fn
  -- Typst stdin is located at the project root, even when cwd differs. Give
  -- templates an explicit root-relative module path for local resources.
  context.MODULE = project_root == "/" and contract.directory or contract.directory:sub(#project_root + 1)
  return context
end

local document_render_serial = 0
local function render_contract(contract, args_source, body_source, scope)
  assert(contract.placement ~= "document", "document bindings are used with #show: name.with(...)")
  if contract.latex_preamble ~= "" and not seen_preambles[contract.latex_preamble] then
    seen_preambles[contract.latex_preamble] = true
    preambles[#preambles + 1] = contract.latex_preamble
  end
  local path
  if contract.asset_argument then
    local named = conversion_arguments(args_source)
    local argument = assert(named[contract.asset_argument], "missing file argument: " .. contract.asset_argument)
    -- Typst 0.15 path(...) values preserve the caller's resource location
    -- when passed to a package. Export the same literal path into assets.
    local path_value = argument:match("^path%s*%((.*)%)$")
    if path_value then argument = trim(path_value) end
    assert(argument:sub(1, 1) == '"' and lex.opaque(argument, 1) == #argument + 1,
      "asset-argument needs a literal file path string or path(\"...\")")
    local resource = import_path(unquote(argument), source_path)
    local input, message = io.open(resource, "rb")
    assert(input, message)
    local data = input:read("*a")
    input:close()
    local filename = "mt2l-" .. pandoc.utils.sha1(data):sub(1, 20) .. "-"
      .. pandoc.path.filename(resource):gsub("[^%w.%-]", "-")
    pandoc.system.make_directory(asset_dir, true)
    pandoc.system.with_temporary_directory(asset_dir, ".mt2l-", function(directory)
      local temporary = pandoc.path.join({ directory, "resource" })
      local output = assert(io.open(temporary, "wb"))
      assert(output:write(data))
      assert(output:close())
      assert(os.rename(temporary, pandoc.path.join({ asset_dir, filename })))
    end)
    exported_assets[pandoc.path.join({ asset_dir, filename })] = true
    path = latex_asset_dir .. "/" .. filename
  end
  if contract.mode == "pdfrender" then
    local rendered, compile_args
    if contract.render_context == "document" then
      document_render_serial = document_render_serial + 1
      local index = tostring(document_render_serial)
      local expression = 'query(<mt2l-render>).filter(el => el.value == ' .. index .. ').map(el => el.location().page())'
      local pages = pandoc.json.decode(pandoc.pipe("typst", {
        "eval", expression, "--root", project_root, "--input", "mt2l-render=" .. index, "--in", source_path,
      }, ""))
      assert(#pages == 1, "document render not found; use standalone calls in document order")
      assert(type(pages[1]) == "number" and pages[1] >= 1 and pages[1] % 1 == 0, "invalid document render page")
      rendered = source_path .. "\n" .. source .. "\nmt2l-render=" .. index
      compile_args = { "compile", "--root", project_root, "--no-pdf-tags", "--input", "mt2l-render=" .. index,
        "--pages", string.format("%d", pages[1]), source_path }
    else
      local kept = {}
      for _, part in ipairs(lex.split(args_source)) do
        if part:match("^([%w_%-]+)%s*:") ~= "mt2l_variables" then kept[#kept + 1] = part end
      end
      local typst_context = context_for(contract, args_source, body_source, scope, true)
      typst_context.HERE = "#" .. contract.fn .. "(" .. table.concat(kept, ", ") .. ")"
      if body_source ~= nil then typst_context.HERE = typst_context.HERE .. "[" .. body_source .. "]" end
      rendered = contract.typst_preamble .. "\n" .. apply_template(contract.typst_template, typst_context)
      compile_args = { "compile", "--root", project_root, "-" }
    end
    -- Content-based names prevent a failed build from overwriting the assets
    -- referenced by a previous successful .tex file. No dependency-blind cache.
    local hash = pandoc.utils.sha1(contract.directory .. "\n" .. rendered):sub(1, 20)
    local filename = "mt2l-" .. contract.alias:gsub("[^%w%-]", "-") .. "-" .. hash .. ".pdf"
    local typst_path = pandoc.path.join({ asset_dir, (filename:gsub("%.pdf$", ".typ")) })
    local pdf_path = pandoc.path.join({ asset_dir, filename })
    pandoc.system.make_directory(asset_dir, true)
    if contract.render_context ~= "document" then
      local file = assert(io.open(typst_path, "w"))
      file:write(rendered)
      file:close()
    end
    -- stdin permits output outside the project without writing temporary files
    -- into an imported module. Resource paths can use $MODULE$ in the template.
    pandoc.system.with_temporary_directory(asset_dir, ".mt2l-", function(directory)
      local temporary_pdf = pandoc.path.join({ directory, "render.pdf" })
      compile_args[#compile_args + 1] = temporary_pdf
      pandoc.pipe("typst", compile_args, contract.render_context == "document" and "" or rendered)
      assert(os.rename(temporary_pdf, pdf_path))
    end)
    exported_assets[pdf_path] = true
    path = latex_asset_dir .. "/" .. filename
  end
  local context = context_for(contract, args_source, body_source, scope, false)
  context.PATH = path
  return apply_template(contract.latex_template, context)
end

local function supplement_inlines(text, scope)
  if text == nil or text == "none" then return nil end
  if text:sub(1, 1) == '"' and lex.opaque(text, 1) == #text + 1 then
    return pandoc.Inlines({ pandoc.Str(unquote(text)) })
  end
  if text:sub(1, 1) == "[" and balanced(text, 1) == #text then text = text:sub(2, -2) end
  local doc = restore(pandoc.read(transform(text, scope), "typst"))
  local inlines = pandoc.Inlines({})
  for _, block in ipairs(doc.blocks) do
    assert(block.t == "Para" or block.t == "Plain", "a reference supplement must be inline content")
    if #inlines > 0 then inlines:insert(pandoc.Space()) end
    inlines:extend(block.content)
  end
  return inlines
end

local function native_call(alias, args_source, scope)
  local named, positional = arguments(args_source)
  if alias == "bibliography" then
    local path = assert(positional[1], "bibliography export needs one literal .bib path")
    local literal = natural.id(trim(path:match("^path%s*%((.*)%)$") or path), lex, unquote)
    assert(literal and literal:lower():match("%.bib$"), "bibliography export needs one literal .bib path")
    local binding = load_module(pandoc.path.join({ converter_root, "mt2l.typ" })).exports.references
    local latex = render_contract(binding, "path: " .. path, nil, scope)
    if named.title and named.title ~= "auto" then
      local title = named.title == "none" and "" or latex_argument(named.title, scope)
      latex = "\\renewcommand{\\refname}{" .. title .. "}\n" .. latex
    end
    if named.full == "true" then latex = "\\nocite{*}\n" .. latex end
    return latex, "block"
  end
  local id = natural.id(positional[1], lex, unquote)
  if not id then return nil end
  local supplement = supplement_inlines(named.supplement, scope)
  if alias == "ref" then
    return natural.reference(id, native_targets, supplement, unquote(named.form or '"normal"')), "inline"
  end
  return natural.citation(id, unquote(named.form or '"normal"'), supplement), "inline"
end

transform = function(text, scope, origin, original)
  local out, start = {}, 1
  local function emit(i, finish, rendered, placement, alias)
    serial = serial + 1
    local marker = prefix .. serial .. "END"
    local before = (original or text):sub(1, i - 1)
    local _, lines = before:gsub("\n", "")
    replacements[marker] = {
      latex = rendered, placement = placement,
      location = (origin or source_path) .. ":" .. (lines + 1) .. " (" .. alias .. ")",
    }
    out[#out + 1] = text:sub(start, i - 1)
    out[#out + 1] = '#("' .. marker .. '")'
    start = finish + 1
    return start
  end
  lex.hashes(text, function(i)
    local alias, after = text:sub(i):match("^#([%w_%-]+[%.%w_%-]*)()")
    local contract = alias and scope[alias]
    local native = not contract and global_values["mt2l-paper"] and (alias == "ref" or alias == "cite" or alias == "bibliography")
    if not contract and not native then return end
    local ok, finish, rendered, placement = pcall(function()
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
      if native then
        local latex, placement = native_call(alias, args_source, scope)
        return close, latex, placement
      end
      if contract.label_argument then
        local id, label_finish = natural.label_after(text, close + 1, lex)
        if id then
          local named = arguments(args_source)
          local existing = named[contract.label_argument]
          assert(not existing or natural.id(existing, lex, unquote) == id, "id and trailing label must match")
          if not existing then
            args_source = args_source .. (trim(args_source) ~= "" and ", " or "") .. contract.label_argument .. ": " .. pandoc.json.encode(id)
          end
          close = label_finish
        end
      end
      return close, render_contract(contract, args_source, body_source, scope), contract.placement
    end)
    if not ok then
      diagnostic(origin or source_path, original or text, i,
        "contract " .. alias .. ": " .. tostring(finish):gsub("^[^\n]-%.lua:%d+: ", ""))
    end
    if rendered then return emit(i, finish, rendered, placement, alias) end
  end, function(i, char)
    if char ~= "@" or not global_values["mt2l-paper"] then return end
    local id, finish, supplement = natural.reference_at(text, i, lex)
    if not id then return end
    -- Ordinary @key citations stay with Pandoc. Preserve only information
    -- the installed reader loses: document refs, colon IDs, and supplements.
    if native_targets[id] or supplement ~= nil or id:find(":", 1, true) then
      local latex = natural.reference(id, native_targets, supplement_inlines(supplement and ("[" .. supplement .. "]"), scope))
      return emit(i, finish, latex, "inline", "@" .. id)
    end
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
  -- Let the CLI check published resources after all temporary directories
  -- have been cleaned. Bibliographies and PDFs are permanent output files.
  local manifest_path = os.getenv("MT2L_ASSET_MANIFEST")
  if manifest_path then
    local manifest = assert(io.open(manifest_path, "wb"))
    local paths = {}
    for path in pairs(exported_assets) do paths[#paths + 1] = path end
    table.sort(paths)
    for _, path in ipairs(paths) do assert(manifest:write(path, "\0")) end
    assert(manifest:close())
  end
  return doc
end
