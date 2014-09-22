const BLOCK_SEPARATOR = '\n'#char(17)

function stdinProducer()
  while true
    produce(read(STDIN, Char))
  end
end

function codeBlockProducer()
  code = ""
  for newChar in Task(stdinProducer)
    if newChar == BLOCK_SEPARATOR
      produce(code)
      code = ""
    else
      code = string(code, newChar)
    end
  end
end
