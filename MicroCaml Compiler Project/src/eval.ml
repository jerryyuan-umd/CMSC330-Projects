open MicroCamlTypes
open Utils

exception TypeError of string
exception DeclareError of string
exception DivByZeroError 

(* Provided functions - DO NOT MODIFY *)

(* Adds mapping [x:v] to environment [env] *)
let extend env x v = (x, ref v)::env

(* Returns [v] if [x:v] is a mapping in [env]; uses the
   most recent if multiple mappings for [x] are present *)
let rec lookup env x =
  match env with
  | [] -> raise (DeclareError ("Unbound variable " ^ x))
  | (var, value)::t -> if x = var then !value else lookup t x

(* Creates a placeholder mapping for [x] in [env]; needed
   for handling recursive definitions *)
let extend_tmp env x = (x, ref (Int 0))::env

(* Updates the (most recent) mapping in [env] for [x] to [v] *)
let rec update env x v =
  match env with
  | [] -> raise (DeclareError ("Unbound variable " ^ x))
  | (var, value)::t -> if x = var then (value := v) else update t x v
        
(* Part 1: Evaluating expressions *)

(* Evaluates MicroCaml expression [e] in environment [env],
   returning a value, or throwing an exception on error *)
let rec eval_expr env e = 
  match e with
  | Value (a) -> a
  | ID b -> (try lookup env b with _ -> 
    raise (DeclareError ("")))
  | Not (c) -> (match eval_expr env c with
    | Bool d -> Bool (not d) 
    | _ -> raise (TypeError ("")))
  | Binop (e, f, g) -> 
    (match e, eval_expr env f, eval_expr env g with 
    | Add, Int h, Int i -> Int (h + i)
    | Sub, Int j, Int k -> Int (j - k)
    | Mult, Int l, Int m -> Int (l * m)
    | Div, Int n, Int o -> 
      if o = 0 then raise DivByZeroError else Int (n / o) 
    | Greater, Int p, Int q -> Bool (p > q) 
    | GreaterEqual, Int p, Int q -> Bool (p >= q)
    | Less, Int p, Int q -> Bool (p < q)
    | LessEqual, Int p, Int q -> Bool (p <= q)
    | Concat, String p, String q -> String (p ^ q)
    | Equal, Int p, Int q -> Bool (p = q)
    | Equal, String p, String q -> Bool (p = q)
    | Equal, Bool p, Bool q -> Bool (p = q)
    | NotEqual, Int p, Int q -> Bool (p <> q)
    | NotEqual, String p, String q -> Bool (p <> q)
    | NotEqual, Bool p, Bool q -> Bool (p <> q)
    | Or, Bool p, Bool q -> Bool (p || q)
    | And, Bool p, Bool q -> Bool (p && q)
    | _ -> raise (TypeError ("")))
  | If (a, b, c) -> (match eval_expr env a with
    | Bool true -> eval_expr env b 
    | Bool false -> eval_expr env c
    | _ -> raise (TypeError ("")))
  | Let (a, false, c, d) -> 
    eval_expr (extend env a (eval_expr env c)) d 
  | Let (a, true, c, d) -> 
    let new_env = extend_tmp env a in
    update new_env a (eval_expr new_env c);
    eval_expr new_env d
  | Fun (a, b) -> Closure (env, a, b)
  | FunctionCall (a, b) -> ( 
    match eval_expr env a, eval_expr env b with
    | Closure (c, d, e), g -> eval_expr (extend c d g) e
    | _ -> raise (TypeError ("")))

(* Part 2: Evaluating mutop directive *)

(* Evaluates MicroCaml mutop directive [m] in environment [env],
   returning a possibly updated environment paired with
   a value option; throws an exception on error *)
let eval_mutop env m = match m with
  | NoOp -> ([], None)
  | Expr (a) -> (env, Some (eval_expr env a))
  | Def (a, b) -> let new_env = extend_tmp env a in
    let new_val = eval_expr new_env b in
    update new_env a new_val; (new_env, Some new_val)

    