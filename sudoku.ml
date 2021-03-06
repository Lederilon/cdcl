open Prelude

let p i j d =
  (* 0 <= i, j, d <= 8 *)
  i + 9 * j + 81 * d + 1

let sudoku_encoding grid =
  let clauses = ref [] in
  let nclauses = ref 0 in
  let addc c = clauses := c::!clauses; incr nclauses in

  for i = 0 to 8 do
    for j = 0 to 8 do
      match grid.(i).(j) with
      | 0 ->
        seq 0 8 |> List.map (p i j) |> addc;
        for d = 0 to 8 do
          for d' = d+1 to 8 do
            addc [- (p i j d); - (p i j d')]
          done
        done
      | x ->
        addc [p i j (x-1)];
    done
  done;

  let valid xi (* x1 x2 x3 x4 x5 x6 x7 x8 x9 *) =
    for i = 0 to 8 do
      for j = i + 1 to 8 do
        for d = 0 to 8 do
          addc [- (p (fst xi.(i)) (snd xi.(i)) d); - (p (fst xi.(j)) (snd xi.(j)) d)];
        done
      done
    done
  in

  for i = 0 to 8 do
    aseq 0 8 |> Array.map (fun x -> (i, x)) |> valid;
  done;
  for j = 0 to 8 do
    aseq 0 8 |> Array.map (fun x -> (x, j)) |> valid;
  done;

  List.iter (fun i ->
    List.iter (fun j ->
      valid [|
        (i, j);
        (i, j+1);
        (i, j+2);
        (i+1, j);
        (i+1, j+1);
        (i+1, j+2);
        (i+2, j);
        (i+2, j+1);
        (i+2, j+2);
      |]
    ) [0;3;6]
  ) [0;3;6];

  (729, !nclauses, !clauses)

let sudoku_line get_value =
  for i = 0 to 8 do
    for j = 0 to 8 do
      try for d = 0 to 8 do
          if get_value (p i j d) = Some true then (
            print_int (d+1);
            raise Exit
          )
        done; print_int 0 with Exit -> ();
    done; done

let sudoku_decode get_value =
  for i = 0 to 8 do
    if i mod 3 = 0 then print_endline "-------------";
    for j = 0 to 8 do
      if j mod 3 = 0 then print_char '|';
      try for d = 0 to 8 do
          if get_value (p i j d) = Some true then (
            print_int (d+1);
            raise Exit
          )
        done; print_int 0 with Exit -> ();
    done;
    print_char '|';
    print_newline ();
  done;
  print_endline "-------------"

let _ =
	let pprint = ref false in
	let minisat = ref false in

  Arg.parse [
      "-v", Arg.Unit (fun () -> Debug.set_verbosity 1), "Print debug message and execute runtime tests";
      "-pprint", Arg.Set pprint, "Pretty-print the solution as a sudoku grid";
      "-minisat", Arg.Set minisat, "Use minisat instead of the internal solver";
    ] (fun _ -> ()) "Usage: ./sudoku-solver < sudoku_instance";

  let input_buf =  dump_chan stdin in
  close_in stdin;

  let m = Array.make_matrix 9 9 0 in
  for i = 0 to 8 do
    for j = 0 to 8 do
      m.(i).(j) <- (int_of_char @@ Buffer.nth input_buf (i * 9 + j)) - (int_of_char '0')
    done
  done;
  let cnf = sudoku_encoding m in

  let st = Sat.init_state cnf in
  match Sat.cdcl st with
  | Sat.UnSat -> print_endline "NoSolution"
  | Sat.Sat a ->
    if not (Verif.verif cnf a) then
      print_endline ">> BUG <<";
    if (!minisat) then (
      let (c_in, c_out) = Unix.open_process "minisat -verb=0 /dev/stdin /dev/stdout" in
      let output_buff = Buffer.create 257 in
      Cnf.buffer_out cnf output_buff;
      Buffer.output_buffer c_out output_buff;
      flush c_out;(*
      print_endline (input_line c_in);
      flush stdout;*)
      ignore (Unix.close_process (c_in, c_out));
    )
    else (
      if (!pprint) then
        sudoku_decode (fun i -> Some a.(i))
      else (
        print_string "Solution:";
        sudoku_line (fun i -> Some a.(i));
        print_newline ()
    ))
