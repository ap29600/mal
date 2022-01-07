package mal

import "core:fmt"
import "core:slice"
import "core:strings"
import "core:intrinsics"
import "core:os"
import "core:io"
import "core:bufio"
import c "core:c/libc"

token_regular_expression :: "[[:space:],]+|~@|[][(){}'`~\\^@]|\"([^\"]|\\\\\")*\"|;.*|[^][[:space:]()\\{\\}'`@~,;]+"


line_buffer:= [4096]u8{}
reader := Reader{}

main :: proc () {
  if err, ok := init(&reader, token_regular_expression); !ok { 
    fmt.println(err)
    os.exit(1) 
  }

  stdin_stream, ok := io.to_reader(os.stream_from_handle(os.stdin))
  if !ok { os.exit(1) }
  stdin_reader := bufio.Reader{}
  bufio.reader_init(&stdin_reader, stdin_stream)

  // define a function
  rep("(def! not (fn* (a) (if a false true)))")
  for {
    fmt.print("user> ")
    if input_bytes, err := bufio.reader_read_slice(&stdin_reader, '\n'); err == .None {
      fmt.println(rep(string(input_bytes)))
    } else {
      break
    }
  }

  deinit(&reader)
}

rep :: proc (s: string) -> string { 
  in_ast, err_read := read(s)
  if err_read != .None { 
    if err_read == .EmptyLine do return ""
    return fmt.tprint(err_read) 
  }
  out_ast, err_eval := eval(in_ast)
  if err_eval != .None { return fmt.tprint(err_eval) }
  return print(out_ast)
}

Symbol       :: distinct string
Keyword      :: distinct string
Map          :: distinct []Ast
List         :: distinct []Ast
Vector       :: distinct []Ast
FunctionType :: struct {
  eval: proc(FunctionType, List)->(Ast, EvalError),
  bindings: []Symbol,
  ast: Ast,
  env: ^Env,
}

Ast :: union {
  bool,
  int, 
  string,
  Symbol,
  Keyword,
  List,
  Map,
  Vector,
  ^FunctionType,
}
