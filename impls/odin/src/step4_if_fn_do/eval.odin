package mal

import "core:fmt"
import "core:reflect"


find :: proc(e: ^Env, s: Symbol) -> (res: ^Env, ok:EvalError) {
  if e == nil {
    fmt.printf("'{}' not found", s)
    return nil, .SymbolNotFound
  }
  if s in e.contents { return e, .None }
  return find(e.parent, s)
}


Binding :: struct { a: Ast, splat: bool }
Env :: struct {
  contents: map[Symbol]Binding,
  parent: ^Env,
}

repl_environment := Env { 
  contents = map[Symbol]Binding{
    "+"       = { new_clone(FunctionType{eval = add})       , false },
    "-"       = { new_clone(FunctionType{eval = sub})       , false },
    "*"       = { new_clone(FunctionType{eval = mul})       , false },
    "/"       = { new_clone(FunctionType{eval = div})       , false },
    "<"       = { new_clone(FunctionType{eval = less})      , false },
    ">"       = { new_clone(FunctionType{eval = greater})   , false },
    "<="      = { new_clone(FunctionType{eval = leq})       , false },
    ">="      = { new_clone(FunctionType{eval = geq})       , false },
    "="       = { new_clone(FunctionType{eval = eq})        , false },
    "list"    = { new_clone(FunctionType{eval = make_list}) , false },
    "list?"   = { new_clone(FunctionType{eval = is_list})   , false },
    "empty?"  = { new_clone(FunctionType{eval = is_empty})  , false },
    "count"   = { new_clone(FunctionType{eval = count})     , false },
    "prn"     = { new_clone(FunctionType{eval = prn})       , false },
    "pr-str"  = { new_clone(FunctionType{eval = pr_str})    , false },
    "str"     = { new_clone(FunctionType{eval = str})       , false },
    "println" = { new_clone(FunctionType{eval = println})   , false },
  }, 
  parent = nil,
}

default_env := &repl_environment

construct_new_env :: proc (parent: ^Env, binds: []Symbol, exprs: []Ast) -> (new_env: ^Env, err: EvalError) {
  new_env = new_clone(Env{parent = parent})
  for bind, i in binds { 
    if bind == "&" {
      if len(binds) != i + 2 { fmt.println("variadic arguments should be in tail position"); return nil, .MalformedExpression }
      new_env.contents[binds[i+1]] = { List(exprs[i:] if len(exprs) > i else []Ast{} ), true }
      break
    }
    if len(exprs) <= i { fmt.printf("argument mismatch: expected '{}', found '{}' ", binds, exprs); return nil, .MalformedExpression }
    new_env.contents[bind] = { exprs[i], false }
  }
  return new_env, .None
}

EvalError :: enum {
  None,
  SymbolNotFound,
  IllegalLookup,
  IllegalCall,
  IllegalConversion,
  MalformedExpression,
}

get :: proc (e: ^Env, s: Symbol) -> (res: Binding, err: EvalError) {
  if e == nil { 
    fmt.printf("'{}' not found", s)
    return {}, .SymbolNotFound 
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
      case List: 
      // evaluate the head and try again
      ast[0] = eval(head, env) or_return
      return eval(ast, env)

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
        env.contents[key] = { val, false }
        return val, .None

        case "let*":
        if len(ast) != 3 {
          fmt.printf("'let*' binding statement '{}' is malformed\n", ast)
          return nil, .MalformedExpression
        }
        new_env := construct_new_env(env, {}, {}) or_return
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
          new_env.contents[key] = { eval(pairings[i*2+1], new_env) or_return, false }
        }

        return eval(ast[2], new_env)

        case "fn*":
        if len(ast) != 3 {
          fmt.printf("'fn*' expression is malformed: '{}'\n", ast)
          return nil, .MalformedExpression
        }

        bindings_raw: List
        ok_bindings: bool
        #partial switch bindings in ast[1] {
          case List: bindings_raw = bindings; ok_bindings = true
          case Vector: bindings_raw = List(bindings); ok_bindings = true
        }

        if !ok_bindings {
          fmt.printf("'fn*' bindings must form a list, found '{}'\n", ast[1])
          return nil, .MalformedExpression
        }

        bindings := make([]Symbol, len(bindings_raw))
        for bind, i in bindings_raw {
          bindings[i], ok_bindings = bind.(Symbol)
          if !ok_bindings {
            fmt.printf("'fn*' bindings must be Symbols, found '{}'\n", bind)
            return nil, .MalformedExpression
          }
        }

        return new_clone(FunctionType{
          eval = closure, 
          bindings = bindings, 
          ast = ast[2], 
          env = env,
        }), .None

        case "do":
        if len(ast) == 1 {
          fmt.println("empty 'do' expression")
          return nil, .MalformedExpression
        }
        for elem in ast[1:len(ast) - 1] { eval(elem, env) or_return }
        return eval(ast[len(ast) - 1], env)

        case "if":
        if len(ast) != 3 && len(ast) != 4 {
          fmt.println("'if' expression must have 2 or 3 arguments, found {}: '{}'\n", len(ast) - 1, ast[1:])
          return nil, .MalformedExpression
        }
        
        res := eval(ast[1], env) or_return
        if as_boolean(res) {
          return eval(ast[2], env)  
        } else {
          if len(ast) == 4 { return eval(ast[3], env) }
          else { return nil, .None }
        }

        case:
        evaluated := eval_ast(ast, env) or_return .(List) // this can't fail
        if len(evaluated) == 0 do return evaluated, .None

        head, ok_head := evaluated[0].(^FunctionType)
        if !ok_head {
          fmt.printf("'{}' is not a function\n", evaluated[0])
          return nil, .IllegalCall
        }
        return head->eval(evaluated[1:])
      }

      case ^FunctionType:
      return head->eval(eval_ast(List(ast[1:]), env) or_return .(List))
    }
    fmt.printf("'{}' is not a function\n", ast[0])
    return nil, .IllegalCall
  }
  return eval_ast(ast, env)
}

eval_ast :: proc(ast: Ast, env: ^Env) -> (res: Ast, ok: EvalError) {
  #partial switch ast in ast {
    case Symbol: return get(env, ast) or_return .a, .None

    case List:
    result := make([dynamic]Ast, 0, len(ast))
    for elem in ast {
      // special case for variadic arguments
      if reflect.union_variant_typeid(elem) == Symbol && get(env, elem.(Symbol)) or_return .splat == true {
        for elem in get(env, elem.(Symbol)) or_return .a.(List) { append(&result, elem) }
      } else {
        append(&result, eval(elem, env) or_return)
      }
    }
    return List(result[:]), .None

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

as_boolean :: proc (a: Ast) -> bool {
  switch a in a {
    case bool: return a
    case int: return true 
    case string: return true 
    case Symbol: return true 
    case Keyword: return true 
    case List: return true
    case Vector: return true 
    case Map: return true 
    case ^FunctionType: return true 
    case: return false
  }
}
