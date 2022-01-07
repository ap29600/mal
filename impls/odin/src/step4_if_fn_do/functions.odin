package mal

import "core:fmt"
import "core:reflect"
import "core:slice"
import "core:strings"

add :: proc(_: FunctionType, a:List)->(res: Ast, err: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return nil, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first + second, .None
}

sub :: proc(_: FunctionType, a:List)->(res: Ast, err: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return nil, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first - second, .None
}

mul :: proc(_: FunctionType, a:List)->(res: Ast, err: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return nil, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first * second, .None
}

div :: proc(_: FunctionType, a:List)->(res: Ast, err: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return nil, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first / second, .None
}

less :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return nil, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first < second, .None
}

greater :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return nil, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first > second, .None
}

leq :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return nil, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first <= second, .None
}

geq :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return nil, .MalformedExpression}; 
  first,  ok_0 := a[0].(int)
  second, ok_1 := a[1].(int)
  if !ok_0 || !ok_1 { fmt.println("Not integers: ", a); return nil, .MalformedExpression }
  return first >= second, .None
}

eq :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  if len(a)!=2{ fmt.println("Malformed expression: ", a); return nil, .MalformedExpression}; 
  switch lhs in a[0] {
    case bool:          if rhs, ok := a[1].(bool);          ok { return lhs == rhs, .None } else { return false, .None }
    case int:           if rhs, ok := a[1].(int);           ok { return lhs == rhs, .None } else { return false, .None }
    case string:        if rhs, ok := a[1].(string);        ok { return lhs == rhs, .None } else { return false, .None }
    case Symbol:        if rhs, ok := a[1].(Symbol);        ok { return lhs == rhs, .None } else { return false, .None }
    case Keyword:       if rhs, ok := a[1].(Keyword);       ok { return lhs == rhs, .None } else { return false, .None }
    case ^FunctionType: if rhs, ok := a[1].(^FunctionType); ok { return lhs == rhs, .None } else { return false, .None }
    case List:
    rhs := List{}
    ok_rhs := false
    #partial switch _rhs_ in a[1] {
      case List: rhs = _rhs_; ok_rhs = true
      case Vector: rhs = List(_rhs_); ok_rhs = true
    }
    if !ok_rhs { return false, .None }
    if len(rhs) != len(lhs) { return false, .None }
    for i in 0..<len(lhs) {
      if !(eq({}, List{lhs[i], rhs[i]}) or_return).(bool) { return false, .None }
    }
    return true, .None

    case Vector:
    rhs := Vector{}
    ok_rhs := false
    #partial switch _rhs_ in a[1] {
      case Vector: rhs = _rhs_; ok_rhs = true
      case List: rhs = Vector(_rhs_); ok_rhs = true
    }
    if !ok_rhs { return false, .None }
    if len(rhs) != len(lhs) { return false, .None }
    for i in 0..<len(lhs) {
      if !(eq({}, List{lhs[i], rhs[i]}) or_return).(bool) { return false, .None }
    }
    return true, .None

    case Map:
    rhs := a[1].(Map)
    return eq({}, List{ List(lhs), List(rhs) } )

    case:
    if reflect.union_variant_typeid(a[1]) == nil { return true, .None } else { return false, .None }
  }
}

is_empty :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  return count({}, a) or_return .(int) == 0, .None
}

count :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  tot := 0
  for elem in a {
    switch elem in elem {
      case List:          tot += len(elem); continue
      case Vector:        tot += len(elem); continue
      case Map:           tot += len(elem); continue
      case ^FunctionType: tot += 1;         continue
      case Keyword:       tot += 1;         continue
      case Symbol:        tot += 1;         continue
      case string:        tot += 1;         continue
      case int:           tot += 1;         continue
      case bool:          tot += 1;         continue
      case: continue
    }
  }
  return tot, .None
}

prn :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  fmt.println(pr_str({}, a) or_return)
  return nil, .None
}

println :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  result := make([]string, len(a))
  for elem, i in a { result[i] = print(elem, true, false)}
  fmt.println(strings.join(result, " "))
  return nil, .None
}


pr_str :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  if len(a) == 0 { return string(""), .None }
  result := make([]string, len(a))
  for elem, i in a { result[i] = print(elem, true, true)}
  return strings.join(result, " "), .None
}

str :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  if len(a) == 0 { return string(""), .None }
  result := make([]string, len(a))
  for elem, i in a { result[i] = print(elem, true, false)}
  return strings.concatenate(result), .None
}

is_list :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) {
  if len(a) != 1 { return true, .None }; 
  _,  ok := a[0].(List)
  return ok, .None
}

make_list :: proc (_: FunctionType, a: List) -> (res: Ast, err: EvalError) { return a, .None }

closure :: proc(fn: FunctionType, a:List)->(res: Ast, err: EvalError) {
  new_env := construct_new_env(fn.env, fn.bindings, cast([]Ast)a) or_return
  return eval(fn.ast, new_env)
}
