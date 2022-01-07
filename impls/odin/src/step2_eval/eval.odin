package mal

__add :: proc(a:List)->(res: Ast, ok: bool) {if len(a)!=2{return 0, false}; return a[0].(int)or_return+a[1].(int)or_return,true}
__sub :: proc(a:List)->(res: Ast, ok: bool) {if len(a)!=2{return 0, false}; return a[0].(int)or_return-a[1].(int)or_return,true}
__mul :: proc(a:List)->(res: Ast, ok: bool) {if len(a)!=2{return 0, false}; return a[0].(int)or_return*a[1].(int)or_return,true}
__div :: proc(a:List)->(res: Ast, ok: bool) {if len(a)!=2{return 0, false}; return a[0].(int)or_return/a[1].(int)or_return,true}

repl_environment := map[Symbol]FunctionType {
  "+" = __add,
  "-" = __sub,
  "*" = __mul,
  "/" = __div,
}

eval  :: proc (ast: Ast) -> (res: Ast, ok: bool) {
  #partial switch ast in ast {
    case List:
    evaluated := eval_ast(ast) or_return .(List) or_return
    if len(evaluated) == 0 do return evaluated, true
    return (evaluated[0].(FunctionType) or_return)(evaluated[1:])
  }
  return eval_ast(ast)
}

eval_ast :: proc(ast: Ast) -> (res: Ast, ok: bool) {
  #partial switch ast in ast {
    case Symbol: return repl_environment[ast]

    case List:
    result := make(List, len(ast))
    for elem, i in ast { result[i] = eval(elem) or_return}
    return result, true

    case Map:
    result := make(Map, len(ast))
    for elem, i in ast { result[i] = eval(elem) or_return}
    return result, true

    case Vector:
    result := make(Vector, len(ast))
    for elem, i in ast { result[i] = eval(elem) or_return}
    return result, true
  }
  return ast, true
}

