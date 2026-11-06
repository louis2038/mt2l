-- Shared lexical traversal. Markup quotes/parentheses are prose; code strings
-- and math strings are opaque. This is deliberately not a Typst evaluator.
local M = {}
local opens = { ["("] = ")", ["["] = "]", ["{"] = "}" }
local expression_end, math_end

function M.trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Return the first position after an opaque token, or nil at ordinary source.
function M.opaque(s, i, strings)
  local pair, char = s:sub(i, i + 1), s:sub(i, i)
  local url = strings == false and s:match("^https?://[^%s%[%]<>]+", i)
  if url then return i + #url
  elseif pair == "//" then
    return s:find("\n", i + 2, true) or (#s + 1)
  elseif pair == "/*" then
    local depth, j = 1, i + 2
    while j <= #s do
      local next_pair = s:sub(j, j + 1)
      if next_pair == "/*" then depth, j = depth + 1, j + 2
      elseif next_pair == "*/" then
        depth, j = depth - 1, j + 2
        if depth == 0 then return j end
      else j = j + 1 end
    end
    error("unterminated block comment at byte " .. i, 0)
  elseif char == '"' and strings ~= false then
    local j = i + 1
    while j <= #s do
      if s:sub(j, j) == "\\" then j = j + 2
      elseif s:sub(j, j) == '"' then return j + 1
      else j = j + 1 end
    end
    error("unterminated string at byte " .. i, 0)
  elseif char == "`" then
    local fence = s:match("^`+", i)
    local finish = s:find(fence, i + #fence, true)
    assert(finish, "unterminated raw block at byte " .. i)
    return finish + #fence
  elseif char == "\\" then
    return math.min(i + 2, #s + 1)
  end
end

function M.skip_space(s, i)
  while i <= #s do
    if s:sub(i, i):match("%s") then i = i + 1
    elseif s:sub(i, i + 1) == "//" or s:sub(i, i + 1) == "/*" then i = M.opaque(s, i)
    else break end
  end
  return i
end

function M.balanced(s, start)
  local opening = s:sub(start, start)
  assert(opens[opening], "expected opening delimiter at byte " .. start)
  local markup, i = opening == "[", start + 1
  while i <= #s do
    local finish, char = M.opaque(s, i, not markup), s:sub(i, i)
    if finish then i = finish
    elseif char == opens[opening] then return i
    elseif markup and char == "#" then i = expression_end(s, i) + 1
    elseif markup and char == "$" then i = math_end(s, i) + 1
    elseif opens[char] and (not markup or char == "[") then i = M.balanced(s, i) + 1
    else i = i + 1 end
  end
  error("unterminated delimiter at byte " .. start, 0)
end

expression_end = function(s, start)
  local name = s:match("^#[%w_%.%-]+", start)
  local i = start + (name and #name or 1)
  if not name and s:sub(i, i) == '"' then return M.opaque(s, i) - 1 end
  local finish = i - 1
  i = M.skip_space(s, i)
  if s:sub(i, i) == "(" or s:sub(i, i) == "{" then
    finish = M.balanced(s, i)
    i = M.skip_space(s, finish + 1)
  end
  while s:sub(i, i) == "[" do
    finish = M.balanced(s, i)
    i = M.skip_space(s, finish + 1)
  end
  return finish
end

math_end = function(s, start)
  local i = start + 1
  while i <= #s do
    local finish, char = M.opaque(s, i), s:sub(i, i)
    if finish then i = finish
    elseif char == "$" then return i
    elseif char == "#" then i = expression_end(s, i) + 1
    else i = i + 1 end
  end
  error("unterminated math at byte " .. start, 0)
end

local function walk(s, first, last, mode, on_hash, on_comment, on_markup)
  local i = first
  while i <= last do
    local finish, char = M.opaque(s, i, mode ~= "markup"), s:sub(i, i)
    local jump = not finish and mode == "markup" and on_markup and on_markup(i, char)
    if jump then i = jump
    elseif finish then
      if on_comment and (s:sub(i, i + 1) == "//" or s:sub(i, i + 1) == "/*") then
        on_comment(i, finish - 1)
      end
      i = finish
    elseif mode == "markup" and char == "$" then
      finish = math_end(s, i)
      walk(s, i + 1, finish - 1, "math", on_hash, on_comment, on_markup)
      i = finish + 1
    elseif char == "#" then
      local jump = on_hash and on_hash(i)
      if jump then i = jump
      elseif on_hash and s:sub(i):match("^#let%f[^%w_%-]") then
        -- Dynamic calls within definitions are outside the source contract API.
        i = M.statement_end(s, i) + 1
      else
        finish = expression_end(s, i)
        walk(s, i + 1, finish, "code", on_hash, on_comment, on_markup)
        i = finish + 1
      end
    elseif mode == "code" and opens[char] then
      finish = M.balanced(s, i)
      walk(s, i + 1, finish - 1, char == "[" and "markup" or "code", on_hash, on_comment, on_markup)
      i = finish + 1
    else i = i + 1 end
  end
end

function M.without_comments(s)
  local spans = {}
  walk(s, 1, #s, "code", nil, function(first, last) spans[#spans + 1] = { first, last } end)
  return M.remove_spans(s, spans)
end

function M.split(s)
  local parts, start, i = {}, 1, 1
  while i <= #s do
    local finish, char = M.opaque(s, i), s:sub(i, i)
    if finish then i = finish
    elseif opens[char] then i = M.balanced(s, i) + 1
    elseif char == "," then
      parts[#parts + 1] = M.trim(M.without_comments(s:sub(start, i - 1)))
      i, start = i + 1, i + 1
    else i = i + 1 end
  end
  local last = M.trim(M.without_comments(s:sub(start)))
  if last ~= "" then parts[#parts + 1] = last end
  return parts
end

-- One top-level statement, including parenthesized multiline expressions.
function M.statement_end(s, start)
  local i = start
  while i <= #s do
    local finish, char = M.opaque(s, i), s:sub(i, i)
    if finish then
      if s:sub(i, i + 1) == "//" then
        local before = M.trim(M.without_comments(s:sub(start, i - 1)))
        if not before:match("[,:=]$") and not before:match("=>$") then return finish - 1 end
      end
      i = finish
    elseif opens[char] then i = M.balanced(s, i) + 1
    elseif char == "\n" then
      local before = M.trim(M.without_comments(s:sub(start, i - 1)))
      if not before:match("[,:=]$") and not before:match("=>$") then return i - 1 end
      i = i + 1
    else i = i + 1 end
  end
  return #s
end

function M.hashes(s, visit, markup)
  walk(s, 1, #s, "markup", visit, nil, markup)
end

function M.remove_spans(s, spans)
  table.sort(spans, function(a, b) return a[1] > b[1] end)
  for _, span in ipairs(spans) do
    -- Retain source positions for diagnostics after declarations are removed.
    s = s:sub(1, span[1] - 1) .. s:sub(span[1], span[2]):gsub("[^\n]", " ") .. s:sub(span[2] + 1)
  end
  return s
end

return M
