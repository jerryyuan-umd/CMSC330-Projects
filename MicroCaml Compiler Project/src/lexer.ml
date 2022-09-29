open TokenTypes
open String

(* Part 1: Lexer - IMPLEMENT YOUR CODE BELOW *)

let peek s pos = 
  if sub s pos 1 = " " || sub s pos 1 = "\n" || sub s pos 1 = "\t" then
    true 
  else false;;

let tokenize input = 
  let re_intn = Str.regexp "(-[0-9]+)" in
  let re_intp = Str.regexp "[0-9]+" in
  let re_string = Str.regexp "\"[^\"]*\"" in
  let re_id = Str.regexp "[a-zA-Z][a-zA-Z0-9]*" in
  let re_lparen = Str.regexp "(" in
  let re_rparen = Str.regexp ")" in
  let re_eq = Str.regexp "=" in
  let re_neq = Str.regexp "<>" in
  let re_grtr = Str.regexp ">" in
  let re_lss = Str.regexp "<" in
  let re_greq = Str.regexp ">=" in
  let re_lseq = Str.regexp "<=" in
  let re_or = Str.regexp "||" in
  let re_and = Str.regexp "&&" in
  let re_not = Str.regexp "not" in
  let re_if = Str.regexp "if" in
  let re_then = Str.regexp "then" in
  let re_else = Str.regexp "else" in
  let re_add = Str.regexp "+" in
  let re_sub = Str.regexp "-" in
  let re_mult = Str.regexp "*" in
  let re_div = Str.regexp "/" in
  let re_concat = Str.regexp "\\^" in
  let re_let = Str.regexp "let" in
  let re_def = Str.regexp "def" in
  let re_in = Str.regexp "in" in
  let re_rec = Str.regexp "rec" in
  let re_fun = Str.regexp "fun" in
  let re_arrow = Str.regexp "->" in
  let re_dblsm = Str.regexp ";;" in
  let rec tok pos s =
    if pos >= length s then []
    else if peek s pos then
      tok (pos + 1) s 
    else if Str.string_match re_string s pos then
      let token = Str.matched_string s in
      Tok_String((sub token 1 ((length token) - 2))) :: tok (pos + (length token)) s
    else if Str.string_match re_intp s pos then
      let token = Str.matched_string s in
        Tok_Int(int_of_string token) :: tok (pos + (length token)) s
    else if Str.string_match re_intn s pos then
      let token = Str.matched_string s in
      let a = sub token 2 (length token - 3) in 
        Tok_Int(-(int_of_string a)) :: tok (pos + (length token)) s
    else if Str.string_match re_lparen s pos then
      Tok_LParen :: tok (pos + 1) s
    else if Str.string_match re_rparen s pos then
      Tok_RParen :: tok (pos + 1) s
    else if Str.string_match re_greq s pos then
      Tok_GreaterEqual :: tok (pos + 2) s
    else if Str.string_match re_lseq s pos then
      Tok_LessEqual :: tok (pos + 2) s
    else if Str.string_match re_eq s pos then
      Tok_Equal :: tok (pos + 1) s
    else if Str.string_match re_neq s pos then
      Tok_NotEqual :: tok (pos + 2) s
    else if Str.string_match re_grtr s pos then
      Tok_Greater :: tok (pos + 1) s
    else if Str.string_match re_lss s pos then
      Tok_Less :: tok (pos + 1) s
    else if Str.string_match re_or s pos then
      Tok_Or :: tok (pos + 2) s
    else if Str.string_match re_and s pos then
      Tok_And :: tok (pos + 2) s
    else if Str.string_match re_not s pos && peek s (pos + 3) then
      Tok_Not :: tok (pos + 3) s
    else if Str.string_match re_if s pos && peek s (pos + 2) then
      Tok_If :: tok (pos + 2) s
    else if Str.string_match re_then s pos && peek s (pos + 4) then
      Tok_Then :: tok (pos + 4) s
    else if Str.string_match re_else s pos && peek s (pos + 4) then
      Tok_Else :: tok (pos + 4) s
    else if Str.string_match re_arrow s pos then
      Tok_Arrow :: tok (pos + 2) s
    else if Str.string_match re_add s pos then
      Tok_Add :: tok (pos + 1) s
    else if Str.string_match re_sub s pos then
      Tok_Sub :: tok (pos + 1) s
    else if Str.string_match re_mult s pos then
      Tok_Mult :: tok (pos + 1) s
    else if Str.string_match re_div s pos then
      Tok_Div :: tok (pos + 1) s
    else if Str.string_match re_concat s pos then
      Tok_Concat :: tok (pos + 1) s
    else if Str.string_match re_def s pos && peek s (pos + 3) then
      Tok_Def :: tok (pos + 3) s
    else if Str.string_match re_let s pos && peek s (pos + 3) then
      Tok_Let :: tok (pos + 3) s
    else if Str.string_match re_in s pos && peek s (pos + 2) then
      Tok_In :: tok (pos + 2) s
    else if Str.string_match re_rec s pos && peek s (pos + 3) then
      Tok_Rec :: tok (pos + 3) s
    else if Str.string_match re_fun s pos && peek s (pos + 3) then
      Tok_Fun :: tok (pos + 3) s
    else if Str.string_match re_id s pos then
      let token = Str.matched_string s in
        match token with "true" ->
          Tok_Bool(true) :: tok (pos + (length token)) s
          | "false" -> 
            Tok_Bool(false) :: tok (pos + (length token)) s
          | _ ->
            Tok_ID(token) :: tok (pos + (length token)) s
    else if Str.string_match re_dblsm s pos then
      Tok_DoubleSemi :: tok (pos + 2) s
    else raise (InvalidInputException ("not found"))
  in
  tok 0 input;;