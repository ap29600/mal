package mal

import "core:fmt"

add :: proc(a:List)->(res: Ast, ok: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return 0, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first + second, .None
}

sub :: proc(a:List)->(res: Ast, ok: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return 0, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first - second, .None
}

mul :: proc(a:List)->(res: Ast, ok: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return 0, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first * second, .None
}

div :: proc(a:List)->(res: Ast, ok: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return 0, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first / second, .None
}

find :: proc(e: ^Env, s: Symbol) -> (res: ^Env, ok:EvalError) {
  if e == nil {
    fmt.printf("'{}' not found", s)
    return nil, .SymbolNotFound
  }
  if s in e.contents { return e, .None }
  return find(e.parent, s)
}

Env :: struct {
  contents: map[Symbol]Ast,
  parent: ^Env,
}

repl_environment := Env { 
  contents = map[Symbol]Ast {
    "+" = FunctionType(add),
    "-" = FunctionType(sub),
    "*" = FunctionType(mul),
    "/" = FunctionType(div),
  }, 
  parent = nil,
}

default_env := &repl_environment

EvalError :: enum {
  None,
  SymbolNotFound,
  IllegalLookup,
  IllegalCall,
  MalformedExpression,
}

get :: proc (e: ^Env, s: Symbol) -> (res: Ast, err: EvalError) {
  if e == nil { 
    fmt.printf("'{}' not found", s)
    return nil, .SymbolNotFound 
  }
  val, ok_val := e.contents[s] 
  if ok_val { return val, .None }
  return get(e.parent, s)
}

eval  :: proc (ast: Ast, env := default_env) -> (res: Ast, err: EvalError) {
  #partial switch ast in ast {
    case List:
    if len(ast) == 0 do return ast, .None
    #partial switch head in ast[0] {
      case Symbol:
      switch head {
        case "def!":
        if len(ast) != 3 {
          fmt.printf("'def!' binding statement '{}' is malformed\n", ast)
          return nil, .MalformedExpression
        }

        key, ok_key := ast[1].(Symbol)
        if !ok_key { return nil, .IllegalLookup }
        val := eval(ast[2], env) or_return
        env.contents[key] = val 
        return val, .None

        case "let*":
        if len(ast) != 3 {
          fmt.printf("'let*' binding statement '{}' is malformed\n", ast)
          return nil, .MalformedExpression
        }
        new_env := new_clone(Env{parent = env})
        defer free(new_env)

        pairings: []Ast = nil
        #partial switch inner in ast[1] {
          case List:    pairings = ([]Ast)(inner)
          case Vector:  pairings = ([]Ast)(inner)
        }
        if pairings == nil || len(pairings) % 2 != 0 {
          fmt.printf("'let*' binding list '{}' is malformed\n", ast[1])
          return nil, .MalformedExpression 
        }

        for i in 0..<len(pairings)/2 {
          key, ok_key := pairings[2*i].(Symbol)
          if !ok_key { 
            fmt.printf("'let*' binding key '{}' is not a symbol\n", key)
            return nil, .IllegalLookup
          }
          new_env.contents[key] = eval(pairings[i*2+1], new_env) or_return
        }

        return eval(ast[2], new_env)

        case:
        evaluated := eval_ast(ast, env) or_return .(List) // this can't fail
        if len(evaluated) == 0 do return evaluated, .None

        head, ok_head := evaluated[0].(FunctionType)
        if !ok_head {
          fmt.printf("'{}' is not a function\n", evaluated[0])
          return nil, .IllegalCall
        }
        return head(evaluated[1:])
      }
    }
    fmt.printf("'{}' is not a function\n", ast[0])
    return nil, .IllegalCall
  }
  return eval_ast(ast, env)
}

eval_ast :: proc(ast: Ast, env: ^Env) -> (res: Ast, ok: EvalError) {
  #partial switch ast in ast {
    case Symbol: return get(env, ast)

    case List:
    result := make(List, len(ast))
    for elem, i in ast {result[i] = eval(elem, env) or_return}
    return result, .None

    case Map:
    result := make(Map, len(ast))
    for elem, i in ast {result[i] = eval(elem, env) or_return}
    return result, .None

    case Vector:
    result := make(Vector, len(ast))
    for elem, i in ast {result[i] = eval(elem, env) or_return}
    return result, .None
  }
  return ast, .None
}

