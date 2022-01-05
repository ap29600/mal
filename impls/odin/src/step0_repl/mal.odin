package mal

import "core:fmt"
import "core:slice"
import "core:os"

line_buffer:= [4096]u8{}

main :: proc () {
  for {
    fmt.print("user> ")
    if line_len, errno := os.read(os.stdin, line_buffer[:]); errno == 0  && line_len > 0{
      input_string := string(line_buffer[:line_len])
      fmt.print(rep(input_string))
    } else {
      break
    }
  }
}

rep :: proc (s: string) -> string { return print(read(eval(s)))}

read  :: proc (s: string) -> string { return s }
eval  :: proc (s: string) -> string { return s }
print :: proc (s: string) -> string { return s }

