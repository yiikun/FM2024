const num_clients : 18;

type message : enum{empty, req_shared, req_exclusive, invalidate,
		      invalidate_ack, grant_shared, grant_exclusive};

     cache_state : enum{invalid, shared, exclusive};

     client: 1 .. num_clients;

var channel1: array[client] of message;

    channel2_4: array[client] of message;

    channel3: array[client] of message;

    home_sharer_list, home_invalidate_list: array[client] of boolean;

    home_exclusive_granted: boolean;

    home_current_command: message;

    home_current_client: client;

    cache: array[client] of cache_state;

ruleset cl: client do
 rule "client requests shared access"
      cache[cl] = invalid & channel1[cl] = empty ==> 
        begin channel1[cl] := req_shared end;

 rule "client requests exclusive access"
      (cache[cl] = invalid | cache[cl] = shared ) & channel1[cl] = empty ==> 
        begin channel1[cl] := req_exclusive end;

 rule "home picks new request"
       home_current_command = empty & channel1[cl] != empty ==>
        begin home_current_command := channel1[cl]; 
              channel1[cl] := empty;
              home_current_client := cl;
              for i: client do
               home_invalidate_list[i] := home_sharer_list[i]
              endfor;
        end;

 rule "home sends invalidate message"
      (home_current_command = req_shared & home_exclusive_granted
       | home_current_command = req_exclusive)
      & home_invalidate_list[cl] & channel2_4[cl] = empty ==>
       begin
        channel2_4[cl] := invalidate;
        home_invalidate_list[cl] := false;
       end;

 rule "home receives invalidate acknowledgement"
      home_current_command != empty & channel3[cl] = invalidate_ack ==>
      begin 
       home_sharer_list[cl] := false;
       home_exclusive_granted := false;
       channel3[cl] := empty;
      end;

 rule "sharer invalidates cache"
      channel2_4[cl] = invalidate & channel3[cl] = empty ==>
      begin
       channel2_4[cl] := empty;
       channel3[cl] := invalidate_ack;
       cache[cl] := invalid;
      end;

 rule "client receives shared grant"
      channel2_4[cl] = grant_shared ==>
      begin
       cache[cl] := shared;
       channel2_4[cl] := empty;
      end;

 rule "client received exclusive grant"
      channel2_4[cl] = grant_exclusive ==>
      begin
       cache[cl] := exclusive;
       channel2_4[cl] := empty;
      end;

end;



 rule "home sends reply to client -- shared"
      home_current_command = req_shared
      & !home_exclusive_granted & channel2_4[home_current_client] = empty ==>
      begin
       home_sharer_list[home_current_client] := true;
       home_current_command := empty;
       channel2_4[home_current_client] := grant_shared;
      end;

 rule "home sends reply to client -- exclusive"
      home_current_command = req_exclusive
      & forall i: client do home_sharer_list[i] = false endforall
      & channel2_4[home_current_client] = empty ==>
      begin
       home_sharer_list[home_current_client] := true;
       home_current_command := empty;
/*        home_exclusive_granted := true;   ERROR */
       channel2_4[home_current_client] := grant_exclusive;
      end;
   




startstate
begin
 for i: client do
   channel1[i] := empty;
   channel2_4[i] := empty; 
   channel3[i] := empty;   
   cache[i] := invalid;
   home_sharer_list[i] := false;
   home_invalidate_list[i] := false;
  endfor;
home_current_command := empty;
home_current_client := 1;
home_exclusive_granted := false;
end;

 invariant "coherent"
  -- (c1 != c2 & cache[c1] = exclusive) -> cache[c2] = invalid
 -- ! (cache[1] = exclusive & cache[2] = shared);
 -- (cache[1] = exclusive -> cache[2] = invalid);
    !(cache[1] = exclusive & cache[2] = shared);