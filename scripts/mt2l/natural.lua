-- Keep Pandoc's math and citation AST. Bridge only the paper semantics that
-- its Typst reader does not retain (labels, reference types, citation options).
local M = {}
local writer = { cite_method = "natbib" }

function M.id(value, lex, unquote)
  if not value then return nil end
  value = lex.trim(value)
  if value:sub(1, 1) == '"' and lex.opaque(value, 1) == #value + 1 then return unquote(value) end
  return value:match("^<([^<>]+)>$")
end

function M.label_after(text, offset, lex)
  local start = lex.skip_space(text, offset)
  local id, after = text:sub(start):match("^<([^<>%s]+)>()")
  if id then return id, start + after - 2 end
end

function M.reference_at(text, offset, lex)
  if text:sub(offset, offset) ~= "@" then return nil end
  if offset > 1 and text:sub(offset - 1, offset - 1):match("[%w_@]") then return nil end
  local id = text:sub(offset + 1):match("^([%w_:%./%-\128-\255]+)")
  if not id then return nil end
  id = id:gsub("[%.:]+$", "")
  if id == "" then return nil end
  local finish = offset + #id
  local supplement
  if text:sub(finish + 1, finish + 1) == "[" then
    local close = lex.balanced(text, finish + 1)
    supplement, finish = text:sub(finish + 2, close - 1), close
  end
  return id, finish, supplement
end

local function prose(inlines)
  return pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "latex", writer):gsub("%s+$", "")
end

function M.reference(id, targets, supplement, form)
  if not targets[id] then return M.citation(id, "normal", supplement) end
  if form == "page" then return "\\pageref{" .. id .. "}" end
  if supplement then
    local prefix = prose(supplement)
    local number = "\\ref*{" .. id .. "}"
    if targets[id] == "equation" then number = "(" .. number .. ")" end
    return "\\hyperref[" .. id .. "]{" .. prefix .. (prefix ~= "" and "~" or "") .. number .. "}"
  end
  return "\\cref{" .. id .. "}"
end

function M.citation(id, form, supplement)
  if form == "none" then return "\\nocite{" .. id .. "}" end
  if form == "author" then return "\\citeauthor{" .. id .. "}" end
  if form == "year" then return "\\citeyear{" .. id .. "}" end
  assert(form == "normal" or form == "prose", "native cite export supports normal, prose, author, year, or none")
  local citation = pandoc.Citation(id, form == "prose" and "AuthorInText" or "NormalCitation", {}, supplement or {})
  return prose({ pandoc.Cite({}, { citation }) })
end

function M.restore(doc, targets)
  return doc:walk({
    Link = function(el)
      local id = el.target:match("^#(.+)$")
      if id and el.classes:includes("ref") and targets[id] then
        return pandoc.RawInline("latex", M.reference(id, targets))
      end
    end,
    Cite = function(el)
      local ids = {}
      for _, cite in ipairs(el.citations) do
        if not targets[cite.id] then return nil end
        ids[#ids + 1] = cite.id
      end
      if #ids > 0 then return pandoc.RawInline("latex", "\\cref{" .. table.concat(ids, ",") .. "}") end
    end,
    Span = function(el)
      if targets[el.identifier] == "equation" and #el.content == 1
        and el.content[1].t == "Math" and el.content[1].mathtype == "DisplayMath" then
        return pandoc.RawInline("latex", "\\begin{equation}\\label{" .. el.identifier .. "}\n" .. el.content[1].text .. "\n\\end{equation}")
      end
    end,
    Inlines = function(inlines)
      local out, i = pandoc.Inlines({}), 1
      while i <= #inlines do
        local el, next_index = inlines[i], i + 1
        if el.t == "Math" and el.mathtype == "DisplayMath" then
          while inlines[next_index] and (inlines[next_index].t == "Space" or inlines[next_index].t == "SoftBreak") do next_index = next_index + 1 end
          local label = inlines[next_index]
          if label and label.t == "Span" and #label.content == 0 and targets[label.identifier] == "equation" then
            out:insert(pandoc.RawInline("latex", "\\begin{equation}\\label{" .. label.identifier .. "}\n" .. el.text .. "\n\\end{equation}"))
            i = next_index + 1
          else out:insert(el); i = i + 1 end
        else out:insert(el); i = i + 1 end
      end
      return out
    end,
  })
end

return M
