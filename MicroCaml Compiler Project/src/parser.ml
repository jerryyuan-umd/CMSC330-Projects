open MicroCamlTypes
open Utils
open TokenTypes
open String
open List

(* Provided functions - DO NOT MODIFY *)

(* Matches the next token in the list, throwing an error if it doesn't match the given token *)
let match_token (toks: token list) (tok: token) =
  match toks with
  | [] -> raise (InvalidInputException(string_of_token tok))
  | h::t when h = tok -> t
  | h::_ -> raise (InvalidInputException(
      Printf.sprintf "Expected %s from input %s, got %s"
        (string_of_token tok)
        (string_of_list string_of_token toks)
        (string_of_token h)))

(* Matches a sequence of toks given as the second list in the order in which they appear, throwing an error if they don't match *)
let match_many (toks: token list) (to_match: token list) =
  List.fold_left match_token toks to_match

(* Return the next token in the token list as an option *)
let lookahead (toks: token list) = 
  match toks with
  | [] -> None
  | h::t -> Some h

(* Return the token at the nth index in the token list as an option*)
let rec lookahead_many (toks: token list) (n: int) = 
  match toks, n with
  | h::_, 0 -> Some h
  | _::t, n when n > 0 -> lookahead_many t (n-1)
  | _ -> None

(* Part 2: Parsing expressions *)
let rec truncate1 lst token = 
  match lst with 
  | [] -> []
  | h::t -> if h = token then [] else h::(truncate1 t token)

let rec truncate2 lst token = 
  match lst with
  | [] -> []
  | h::t -> if h = token then t else truncate2 t token

let rec truncate3 lst lev inc =
  match lst, lev with
  | [], _ -> []
  | h::t, 0 -> if h = Tok_RParen && inc then [h] 
    else if h = Tok_RParen && not inc then [] 
    else if h = Tok_LParen then h::(truncate3 t 1 inc) else h::(truncate3 t 0 inc)
  | h::t, n -> match h with
    | Tok_RParen -> h::(truncate3 t (n - 1) inc)
    | Tok_LParen -> h::(truncate3 t (n + 1) inc)
    | _ -> h::(truncate3 t n inc)

let rec truncate4 lst lev =
  match lst, lev with
  | [], _ -> []
  | h::t, 0 -> if h = Tok_RParen then t  
    else if h = Tok_LParen then truncate4 t 1 else truncate4 t 0
  | h::t, n -> match h with
    | Tok_RParen -> truncate4 t (n - 1)
    | Tok_LParen -> truncate4 t (n + 1)
    | _ -> truncate4 t n

let rec parse_exp toks = 
  try parse_orExpr toks with _ -> 
    try parse_functionExpr toks with _ ->
      try parse_ifExpr toks with _ ->
        try parse_letExpr toks with _ ->
          raise (InvalidInputException ("You failed"))
and parse_letExpr toks =
  let cut = match_token toks Tok_Let in
  let cut2 = if parse_rec cut then match_token cut Tok_Rec else cut in
  match lookahead cut2 with 
  | Some (Tok_ID(a)) -> 
    (let cut3 = match_token (match_token cut2 (Tok_ID(a))) Tok_Equal in 
      match 
        try find (fun x -> x = Tok_In) toks with _ ->
          raise (InvalidInputException ("no Tok_In"))
      with _ -> Let (a, (parse_rec cut), 
        parse_exp (truncate1 cut3 Tok_In), 
          parse_exp (truncate2 cut3 Tok_In)))
  | _ -> raise (InvalidInputException ("no ID in let"))
and parse_rec toks =
  match lookahead toks with
  | Some Tok_Rec -> true  
  | _ -> false
and parse_orExpr toks = match toks with [] -> raise (InvalidInputException ("")) | _ -> 
  try parse_andExpr toks with _ ->
    Binop (Or, parse_andExpr (truncate1 toks Tok_Or),
      parse_orExpr (truncate2 toks Tok_Or))
and parse_functionExpr toks = 
  let cut = match_token toks Tok_Fun in
  match lookahead cut with 
  | Some Tok_ID(a) -> (match cut with
    | [] -> raise (InvalidInputException (""))
    | h::t -> Fun (a, parse_exp (match_token t Tok_Arrow)))
  | _ -> raise (InvalidInputException (""))
and parse_ifExpr toks = 
  let cut = match_token toks Tok_If in
  let cut2 = truncate1 cut Tok_Then in
  If (parse_exp cut2, parse_exp (truncate1 (truncate2 cut Tok_Then) 
    Tok_Else), parse_exp (truncate2 (truncate2 cut Tok_Then) Tok_Else)) 
and parse_andExpr toks = match toks with [] -> raise (InvalidInputException ("")) | _ ->
  try parse_eqExpr toks with _ ->
    Binop (And, parse_eqExpr (truncate1 toks Tok_And),
      parse_andExpr (truncate2 toks Tok_And))
and parse_eqExpr toks = match toks with [] -> raise (InvalidInputException ("")) | _ -> 
  try parse_relExpr toks with _ ->
    try Binop (Equal, parse_relExpr (truncate1 toks Tok_Equal),
      parse_eqExpr (truncate2 toks Tok_Equal)) with _ ->
        Binop (NotEqual, parse_relExpr (truncate1 toks Tok_NotEqual),
          parse_eqExpr (truncate2 toks Tok_NotEqual))
and parse_relExpr toks = match toks with [] -> raise (InvalidInputException ("")) | _ ->
  try parse_addExpr toks with _ ->
    try Binop (Less, parse_addExpr (truncate1 toks Tok_Less),
      parse_relExpr (truncate2 toks Tok_Less)) with _ ->
        try Binop (Greater, parse_addExpr (truncate1 toks Tok_Greater),
          parse_relExpr (truncate2 toks Tok_Greater)) with _ ->
            try Binop (LessEqual, parse_addExpr (truncate1 toks Tok_LessEqual),
              parse_relExpr (truncate2 toks Tok_LessEqual)) with _ ->
                Binop (GreaterEqual, parse_addExpr (truncate1 toks Tok_GreaterEqual),
                  parse_relExpr (truncate2 toks Tok_GreaterEqual))
and parse_addExpr toks = match toks with [] -> raise (InvalidInputException ("")) | _ -> 
  try parse_multExpr toks with _ ->
    try Binop (Add, parse_multExpr (truncate1 toks Tok_Add),
      parse_addExpr (truncate2 toks Tok_Add)) with _ ->
        Binop (Sub, parse_multExpr (truncate1 toks Tok_Sub),
          parse_addExpr (truncate2 toks Tok_Sub))
and parse_multExpr toks = match toks with [] -> raise (InvalidInputException ("")) | _ -> 
  try parse_concatExpr toks with _ ->
    try Binop (Div, parse_concatExpr (truncate1 toks Tok_Div),
      parse_multExpr (truncate2 toks Tok_Div)) with _ ->
        Binop (Mult, parse_concatExpr (truncate1 toks Tok_Mult),
          parse_multExpr (truncate2 toks Tok_Mult))
and parse_concatExpr toks = match toks with [] -> raise (InvalidInputException ("")) | _ -> 
  try parse_unaryExpr toks with _ ->
    Binop (Concat, parse_unaryExpr (truncate1 toks Tok_Concat),
      parse_concatExpr (truncate2 toks Tok_Concat)) 
and parse_unaryExpr toks = match toks with [] -> raise (InvalidInputException ("")) 
  | h::t -> if h = Tok_Not then Not (parse_unaryExpr t)
    else parse_funCallExpr toks 
and parse_funCallExpr toks = 
  match toks with 
  | [] -> raise (InvalidInputException ("")) 
  | h::t -> try parse_primExpr toks with _ -> 
    if h = Tok_LParen then
      FunctionCall (parse_primExpr ((truncate3 toks (-1) false) @ 
        [Tok_RParen]), parse_primExpr (truncate4 t 0))
    else FunctionCall (parse_primExpr [h], parse_primExpr t)
and parse_primExpr toks = 
  match toks with 
  | h::[] -> (match h with
    | Tok_Int(a) -> Value (Int a)
    | Tok_Bool(a) -> Value (Bool a) 
    | Tok_String(a) -> Value (String a)
    | Tok_ID(a) -> ID a
    | _ -> raise (InvalidInputException ("No")))
  | Tok_LParen::t ->
    (match 
      try find (fun x -> x = Tok_RParen) t with _ ->
        raise (InvalidInputException ("No"))
    with _ -> match truncate4 toks (-1) with 
      | [] -> parse_exp (truncate3 t 0 false)
      | _ -> raise (InvalidInputException ("No")))
  | _ -> raise (InvalidInputException ("No"))   

let rec parse_expr toks = ([], parse_exp toks);; 

(* Part 3: Parsing mutop *)

let rec parse_mutop toks = 
  try ((match_token toks Tok_DoubleSemi), NoOp) with _ -> 
    try parse_exprMutop toks with _ ->
      parse_defMutop toks
and parse_defMutop toks = 
  let cut = match_token toks Tok_Def in
    match lookahead cut with 
    | Some Tok_ID(a) -> (match cut with
      | [] -> raise (InvalidInputException (""))
      | h::t -> (truncate2 toks Tok_DoubleSemi,
        Def (a, parse_exp (truncate1 (match_token t Tok_Equal) Tok_DoubleSemi))))
    | _ -> raise (InvalidInputException (""))
and parse_exprMutop toks =
  (truncate2 toks Tok_DoubleSemi, 
    Expr (parse_exp (truncate1 toks Tok_DoubleSemi)));;