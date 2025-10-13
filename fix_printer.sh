#!/bin/bash

# Find the start_logo function and fix the problematic lines
sed -i '' \
  -e '/"echo '\''#{lines}'\'' | gterm #{gradients}"/,/|> IO.puts()/c\
    # Execute the command and handle the CommandResult properly\
    result = Argos.Command.exec!("echo '\''#{lines}'\'' | gterm #{gradients}")\
    IO.puts(result.output)\
    :ok' \
  lib/aegis/printer.ex