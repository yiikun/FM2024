
Const 
    -- config start
    coreNum: 4;
    allNodeNum: 7;
    allBranchNum: 2;
    -- config end
    
Type
    l1Id: allNodeNum-coreNum+1 .. allNodeNum; 

    cacheId: 1..allNodeNum-coreNum;

    nodeId: 1..allNodeNum;

    branchType: 1.. allBranchNum;

    stateType: enum{None,Trunk,Branch,Tip};

    AType: enum{AcquirePerm, AcquireBlock};

    BType: enum{Probe};

    CType: enum{ReleaseData, ProbeAckData};

    DType: enum{Grant, GrantData, ReleaseAck};

    EType: enum{GrantAck};

    growType: enum{NtoB, NtoT, BtoT};

    capType: enum{toN, toB, toT};

    pruneType: enum{BtoN, TtoN, TtoB, NtoN, BtoB};

    chAType: record
        opcode: AType;
        para: growType;
    end;

    chBType: record
        opcode: BType;
        para: capType;
    end;

    chCType: record
        opcode: CType;
        para: pruneType;
    end;

    chDType: record
        opcode: DType;
        para: capType;
    end;

    chEType: record
        opcode: EType;
    end;

    slave_pending_Type: enum{pending_ProbeAckData, pending_GrantAck};

    master_pending_Type: enum{pending_Grant, pending_GrantData, pending_ReleaseAck};

    cacheType: record
        state: stateType;
    end;

    TreeNode: Record
        cache: cacheType;
        sons: array[branchType] of nodeId;
        directory: array[branchType] of stateType;
        slave_pending: array[branchType] of slave_pending_Type;
        master_pending: master_pending_Type;
        chanA: array[branchType] of chAType;
        chanB: array[branchType] of chBType;
        chanC: array[branchType] of chCType;
        chanD: array[branchType] of chDType;
        chanE: array[branchType] of chEType;
    end;

Var
    Tree: array [nodeId] of TreeNode;

startstate "Init"
var son: 1..allNodeNum+1;
begin
    son := 2;
    for cur : cacheId do 
        Tree[cur].cache.state := None;
        for i : branchType do
            Tree[cur].sons[i] := son;
            undefine Tree[cur].chanA;
            undefine Tree[cur].chanB;
            undefine Tree[cur].chanC;
            undefine Tree[cur].chanD;
            undefine Tree[cur].chanE;
            undefine Tree[cur].master_pending;
            undefine Tree[cur].slave_pending[i];
            Tree[cur].directory[i] := None;
            son := son + 1;
        endfor;
    endfor;

    for cur : l1Id do
        Tree[cur].cache.state := None;
        undefine Tree[cur].master_pending;
    endfor;
endstartstate;

ruleset i: l1Id do
alias j: (i-2)/allBranchNum+1;
      b: i-allBranchNum*(j-1)-1 do
rule "send_AcquireBlock_toB"
    Tree[i].cache.state = None &
    IsUndefined(Tree[i].master_pending)
==>
begin
    Tree[j].chanA[b].opcode  := AcquireBlock;
    Tree[j].chanA[b].para    := NtoB;
    Tree[i].master_pending := pending_GrantData;
endrule;

rule "send_AcquirePerm_toT"
    Tree[i].cache.state = Branch &
    IsUndefined(Tree[i].master_pending)
==>
begin
    Tree[j].chanA[b].opcode  := AcquirePerm;
    Tree[j].chanA[b].para := BtoT;
    Tree[i].master_pending := pending_Grant;
endrule;

rule "send_AcquireBlock_toT"
    Tree[i].cache.state = None &
    IsUndefined(Tree[i].master_pending)
==>
begin
    Tree[j].chanA[b].opcode  := AcquireBlock;
    Tree[j].chanA[b].para := NtoT;
    Tree[i].master_pending := pending_GrantData;
endrule;

rule "send_Release_BtoN"
    Tree[i].cache.state = Branch &
    IsUndefined(Tree[i].master_pending) &
    IsUndefined(Tree[j].chanC[b].opcode)
==>
begin
    Tree[j].chanC[b].opcode := ReleaseData;
    Tree[j].chanC[b].para := BtoN;
    Tree[i].master_pending := pending_ReleaseAck;
    Tree[i].cache.state := None;
endrule;

rule "send_Release_TtoN"
    Tree[i].cache.state = Tip &
    IsUndefined(Tree[i].master_pending) &
    IsUndefined(Tree[j].chanC[b].opcode)
==>
begin
    Tree[j].chanC[b].para := TtoN;
    Tree[j].chanC[b].opcode := ReleaseData;
    Tree[i].master_pending := pending_ReleaseAck;
    Tree[i].cache.state := None;
endrule;
endalias;
endruleset;

-- L1 responds
ruleset i: l1Id do
alias j: (i-2)/allBranchNum+1;
      b: i-allBranchNum*(j-1)-1 do
rule "respond_Grant_toT"
    !IsUndefined(Tree[j].chanD[b].opcode) &
    Tree[j].chanD[b].opcode = Grant &
    Tree[j].chanD[b].para = toT
==>
begin
    Tree[i].cache.state := Tip;
    undefine Tree[j].chanD[b];
    undefine Tree[i].master_pending;
    Tree[j].chanE[b].opcode  := GrantAck; 
endrule;

rule "respond_GrantData_toB"
    !IsUndefined(Tree[j].chanD[b].opcode) &
    Tree[j].chanD[b].opcode = GrantData &
    Tree[j].chanD[b].para = toB
==>
begin
    Tree[i].cache.state := Branch;
    undefine Tree[j].chanD[b];
    undefine Tree[i].master_pending;
    Tree[j].chanE[b].opcode  := GrantAck;
endrule;

rule "respond_GrantData_toT"
    !IsUndefined(Tree[j].chanD[b].opcode) &
    Tree[j].chanD[b].opcode = GrantData &
    Tree[j].chanD[b].para = toT
==>
begin
    Tree[i].cache.state := Tip;
    undefine Tree[j].chanD[b];
    undefine Tree[i].master_pending;
    Tree[j].chanE[b].opcode  := GrantAck;
endrule;

rule "respond_Probe_NtoN"
    !IsUndefined(Tree[j].chanB[b].opcode) &
    (Tree[j].chanB[b].opcode = Probe |
    Tree[j].chanB[b].opcode = Probe) &
    (Tree[j].chanB[b].para = toN | 
    Tree[j].chanB[b].para = toB) &
    IsUndefined(Tree[j].chanC[b].opcode) &
    (!IsUndefined(Tree[i].master_pending) ->
    Tree[i].master_pending != pending_ReleaseAck)&
    Tree[i].cache.state = None
==>
begin
    Tree[j].chanC[b].opcode  := ProbeAckData;
    Tree[j].chanC[b].para    := NtoN;
    undefine Tree[j].chanB[b];
    Tree[i].cache.state := None;
endrule;

rule "respond_Probe_BtoN"
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toN &
    IsUndefined(Tree[j].chanC[b].opcode) &
    (!IsUndefined(Tree[i].master_pending) ->
    Tree[i].master_pending != pending_ReleaseAck)&
    Tree[i].cache.state = Branch
==>
begin
    Tree[j].chanC[b].opcode  := ProbeAckData;
    Tree[j].chanC[b].para    := BtoN; 
    undefine Tree[j].chanB[b];
    Tree[i].cache.state := None;
endrule;

rule "respond_Probe_BtoB"
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toB &
    IsUndefined(Tree[j].chanC[b].opcode) &
    (!IsUndefined(Tree[i].master_pending) ->
    Tree[i].master_pending != pending_ReleaseAck)&
    Tree[i].cache.state = Branch
==>
begin
    Tree[j].chanC[b].opcode  := ProbeAckData;
    Tree[j].chanC[b].para    := BtoB; 
    undefine Tree[j].chanB[b];
endrule;

rule "respond_Probe_TtoN"
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toN &
    IsUndefined(Tree[j].chanC[b].opcode) &
    (!IsUndefined(Tree[i].master_pending) ->
    Tree[i].master_pending != pending_ReleaseAck)&
    Tree[i].cache.state = Tip
==>
begin
    Tree[j].chanC[b].para    := TtoN; 
    Tree[j].chanC[b].opcode  := ProbeAckData;
    undefine Tree[j].chanB[b];
    Tree[i].cache.state := None;
endrule;

rule "respond_Probe_TtoB"
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    IsUndefined(Tree[j].chanC[b].opcode) &
    (!IsUndefined(Tree[i].master_pending) ->
    Tree[i].master_pending != pending_ReleaseAck)&
    Tree[i].cache.state = Tip
==>
begin
    Tree[j].chanC[b].para    := TtoB; 
    Tree[j].chanC[b].opcode  := ProbeAckData;
    Tree[i].cache.state := Branch;
    undefine Tree[j].chanB[b];
endrule;

rule "receive_ReleaseAck"
    !IsUndefined(Tree[j].chanD[b].opcode) &
    Tree[j].chanD[b].opcode = ReleaseAck
==>
begin
    undefine Tree[i].master_pending;
    undefine Tree[j].chanD[b];
endrule;
endalias;
endruleset;

-- Ln <-> Ln+1
ruleset i : cacheId; b : branchType do 
rule "Ln_receive_AcquirePerm_Tip_Branch_None"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquirePerm &
    Tree[i].cache.state = Tip &
    forall k : branchType do
        (k != b -> Tree[i].directory[k] = None) &
        IsUndefined(Tree[i].slave_pending[k]) 
    endforall &
    Tree[i].directory[b] = Branch
==>
begin
    undefine Tree[i].chanA[b];
    Tree[i].chanD[b].opcode := Grant;
    Tree[i].chanD[b].para := toT;
    Tree[i].directory[b] := Tip;
    Tree[i].cache.state := Trunk;
    Tree[i].slave_pending[b] := pending_GrantAck;
endrule;

rule "Ln_receive_AcquirePerm_Tip_None_None"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquirePerm &
    Tree[i].cache.state = Tip &
    forall k : branchType do
        (k != b -> Tree[i].directory[k] = None) &
        IsUndefined(Tree[i].slave_pending[k])
    endforall &
    Tree[i].directory[b] = None
==>
begin
    undefine Tree[i].chanA[b];
    Tree[i].chanD[b].opcode := GrantData;
    Tree[i].chanD[b].para := toT;
    Tree[i].directory[b] := Tip;
    Tree[i].cache.state := Trunk;
    Tree[i].slave_pending[b] := pending_GrantAck;
endrule;

rule "Ln_receive_AcquirePerm_Tip_x_Branch"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquirePerm &
    Tree[i].cache.state = Tip &
    exists k : branchType do
        k != b &
        Tree[i].directory[k] = Branch &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k : branchType do
        if k != b & Tree[i].directory[k] = Branch &
            IsUndefined(Tree[i].slave_pending[k]) then   
            Tree[i].chanB[k].opcode := Probe;
            Tree[i].chanB[k].para := toN;
            Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;

rule "Ln_receive_AcquirePerm_x_None_Tip"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquirePerm &
    Tree[i].directory[b] = None &
    exists k : branchType do
        k != b &
        Tree[i].directory[k] = Tip &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k : branchType do
        if k != b & Tree[i].directory[k] = Branch &
            IsUndefined(Tree[i].slave_pending[k]) then   
            Tree[i].chanB[k].opcode := Probe;
            Tree[i].chanB[k].para := toN;
            Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;

rule "Ln_receive_AcquireBlock_NtoB_Branch/Tip_x_x"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquireBlock &
    Tree[i].chanA[b].para = NtoB &
    (Tree[i].cache.state = Branch | Tree[i].cache.state = Tip) &
    IsUndefined(Tree[i].slave_pending[b])
==>
begin
    undefine Tree[i].chanA[b];
    Tree[i].chanD[b].opcode := GrantData;
    Tree[i].chanD[b].para := toB;
    Tree[i].slave_pending[b] := pending_GrantAck;
    Tree[i].directory[b] := Branch;
endrule;

rule "Ln_receive_AcquireBlock_NtoB_x_None_Tip"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquireBlock &
    Tree[i].chanA[b].para = NtoB &
    exists k : branchType do
        k != b &
        Tree[i].directory[k] = Tip &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k : branchType do
        if k != b & Tree[i].directory[k] = Tip &
           IsUndefined(Tree[i].slave_pending[k]) then       
            Tree[i].chanB[k].opcode := Probe;
            Tree[i].chanB[k].para := toB;
            Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;

rule "Ln_receive_AcquireBlock_NtoB_None_Branch"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquireBlock &
    Tree[i].chanA[b].para = NtoB &
    Tree[i].cache.state = None &
    exists k : branchType do
        k != b &
        Tree[i].directory[k] = Branch &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k : branchType do
        if k != b & Tree[i].directory[k] = Branch &
           IsUndefined(Tree[i].slave_pending[k]) then       
            Tree[i].chanB[k].opcode := Probe;
            Tree[i].chanB[k].para := toB;
            Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;

rule "Ln_receive_AcquireBlock_NtoT_Tip_None_None"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquireBlock &
    Tree[i].chanA[b].para = NtoT &
    Tree[i].cache.state = Tip &
    forall k : branchType do
        Tree[i].directory[k] = None &
        IsUndefined(Tree[i].slave_pending[k])
    endforall
==>
begin
    undefine Tree[i].chanA[b];
    Tree[i].chanD[b].opcode := GrantData;
    Tree[i].chanD[b].para := toT;
    Tree[i].slave_pending[b] := pending_GrantAck;
    Tree[i].cache.state := Trunk;
    Tree[i].directory[b] := Tip;
endrule;

rule "Ln_receive_AcquireBlock_NtoT_Tip_x_Branch"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquireBlock &
    Tree[i].chanA[b].para = NtoT &
    Tree[i].cache.state = Tip &
    exists k : branchType do
        k != b &
        Tree[i].directory[k] = Branch &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k : branchType do
        if k != b & Tree[i].directory[k] = Branch &
            IsUndefined(Tree[i].slave_pending[k]) then
            Tree[i].chanB[k].opcode := Probe;
            Tree[i].chanB[k].para := toN;
            Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;

rule "Ln_receive_AcquireBlock_NtoT_x_None_Tip"
    !IsUndefined(Tree[i].chanA[b].opcode) &
    Tree[i].chanA[b].opcode = AcquireBlock &
    Tree[i].chanA[b].para = NtoT &
    Tree[i].directory[b] = None & 
    exists k : branchType do
        k != b &
        Tree[i].directory[k] = Tip &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k : branchType do
        if k != b & Tree[i].directory[k] = Tip then  
            Tree[i].chanB[k].opcode := Probe;
            Tree[i].chanB[k].para := toN;
            Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;

rule "Ln_receive_ProbeAck_NtoN"
    !IsUndefined(Tree[i].chanC[b].opcode) &
    Tree[i].chanC[b].opcode = ProbeAckData &
    Tree[i].chanC[b].para = NtoN
==>
begin
    Tree[i].directory[b] := None;
    undefine Tree[i].chanC[b];
    undefine Tree[i].slave_pending[b];
endrule;

rule "Ln_receive_ProbeAck_BtoN"
    !IsUndefined(Tree[i].chanC[b].opcode) &
    Tree[i].chanC[b].opcode = ProbeAckData &
    Tree[i].chanC[b].para = BtoN
==>
begin
    if Tree[i].cache.state = None then
        Tree[i].cache.state := Branch;
    endif;
    Tree[i].directory[b] := None;
    undefine Tree[i].chanC[b];
    undefine Tree[i].slave_pending[b];
endrule;

rule "Ln_receive_ProbeAck_BtoB"
    !IsUndefined(Tree[i].chanC[b].opcode) &
    Tree[i].chanC[b].opcode = ProbeAckData &
    Tree[i].chanC[b].para = BtoB
==>
begin
    if Tree[i].cache.state = None then
        Tree[i].cache.state := Branch;
    endif;
    undefine Tree[i].chanC[b];
    undefine Tree[i].slave_pending[b];
endrule;

rule "Ln_receive_ProbeAckData_TtoN"
    !IsUndefined(Tree[i].chanC[b].opcode) &
    Tree[i].chanC[b].opcode = ProbeAckData &
    Tree[i].chanC[b].para = TtoN
==>
begin
    Tree[i].directory[b] := None;
    Tree[i].cache.state := Tip;
    undefine Tree[i].chanC[b];
    undefine Tree[i].slave_pending[b];
endrule;

rule "Ln_receive_ProbeAckData_TtoB"
    !IsUndefined(Tree[i].chanC[b].opcode) &
    Tree[i].chanC[b].opcode = ProbeAckData &
    Tree[i].chanC[b].para = TtoB
==>
begin
    Tree[i].directory[b] := Branch;
    Tree[i].cache.state := Tip;
    undefine Tree[i].chanC[b];
    undefine Tree[i].slave_pending[b];
endrule;

rule "Ln_receive_Release_BtoN"
    !IsUndefined(Tree[i].chanC[b].opcode) &
    Tree[i].chanC[b].opcode = ReleaseData &
    Tree[i].chanC[b].para = BtoN
==>
begin
    Tree[i].directory[b] := None;
    if Tree[i].cache.state = None then
        Tree[i].cache.state := Branch;
    endif; 
    Tree[i].chanD[b].opcode := ReleaseAck;
    undefine Tree[i].chanC[b];
endrule;

rule "Ln_receive_Release_TtoN"
    !IsUndefined(Tree[i].chanC[b].opcode) &
    Tree[i].chanC[b].opcode = ReleaseData &
    Tree[i].chanC[b].para = TtoN
==>
begin
    Tree[i].directory[b] := None;
    Tree[i].cache.state := Tip;
    undefine Tree[i].chanC[b];
    Tree[i].chanD[b].opcode := ReleaseAck;
endrule;

rule "Ln_receive_Release_TtoB"
    !IsUndefined(Tree[i].chanC[b].opcode) &
    Tree[i].chanC[b].opcode = ReleaseData &
    Tree[i].chanC[b].para = TtoB
==>
begin
    Tree[i].directory[b] := Branch;
    Tree[i].cache.state := Tip;
    undefine Tree[i].chanC[b];
    Tree[i].chanD[b].opcode := ReleaseAck;
endrule;

rule "Ln_receive_GrantAck"
    !IsUndefined(Tree[i].chanE[b].opcode) &
    Tree[i].chanE[b].opcode = GrantAck
==>
begin
    undefine Tree[i].chanE[b];
    undefine Tree[i].slave_pending[b];
endrule;
endruleset;

-- Ln+1 <-> Ln <-> Ln-1
ruleset i : cacheId; b1 : branchType do
alias j: (i-2)/allBranchNum+1;
      b2: i-allBranchNum*(j-1)-1 do
rule "Ln_receive_AcquirePerm_Branch_x_x"
    i > 1 &
    !IsUndefined(Tree[i].chanA[b1].opcode) &
    Tree[i].chanA[b1].opcode = AcquirePerm &
    Tree[i].cache.state = Branch & 
    IsUndefined(Tree[i].master_pending)
==>
begin
    Tree[j].chanA[b2].opcode := AcquirePerm;
    Tree[j].chanA[b2].para := BtoT;
    Tree[i].master_pending := pending_Grant;
endrule;

rule "Ln_receive_AcquirePerm_None_Branch_x"
    i > 1 &
    !IsUndefined(Tree[i].chanA[b1].opcode) &
    Tree[i].chanA[b1].opcode = AcquirePerm &
    Tree[i].cache.state = None &
    Tree[i].directory[b1] = Branch &
    IsUndefined(Tree[i].master_pending)
==>
begin
    Tree[j].chanA[b2].opcode := AcquirePerm;
    Tree[j].chanA[b2].para := BtoT;
    Tree[i].master_pending := pending_GrantData;
endrule;

rule "Ln_receive_AcquirePerm_None_None_None"
    i > 1 &
    !IsUndefined(Tree[i].chanA[b1].opcode) &
    Tree[i].chanA[b1].opcode = AcquirePerm &
    Tree[i].cache.state = None &
    forall k: branchType do
        Tree[i].directory[k] = None
    endforall &
    IsUndefined(Tree[i].master_pending)
==>
begin
    Tree[j].chanA[b2].opcode := AcquireBlock;
    Tree[j].chanA[b2].para := NtoT;
    Tree[i].master_pending := pending_GrantData;
endrule;

rule "Ln_receive_AcquireBlock_NtoB_None_None_None"
    i > 1 &
    !IsUndefined(Tree[i].chanA[b1].opcode) &
    Tree[i].chanA[b1].opcode = AcquireBlock &
    Tree[i].chanA[b1].para = NtoB &
    Tree[i].cache.state = None &
    forall k: branchType do
        Tree[i].directory[k] = None
    endforall &
    IsUndefined(Tree[i].master_pending)
==>
begin
    Tree[j].chanA[b2].opcode := AcquireBlock;
    Tree[j].chanA[b2].para := NtoB;
    Tree[i].master_pending := pending_GrantData;
endrule;

rule "Ln_receive_AcquireBlock_NtoT_None_None_None"
    i > 1 &
    !IsUndefined(Tree[i].chanA[b1].opcode) &
    Tree[i].chanA[b1].opcode = AcquireBlock &
    Tree[i].chanA[b1].para = NtoT &
    Tree[i].cache.state = None &
    forall k: branchType do
        Tree[i].directory[k] = None
    endforall &
    IsUndefined(Tree[i].master_pending)
==>
begin
    Tree[j].chanA[b2].opcode := AcquireBlock;
    Tree[j].chanA[b2].para := NtoT;
    Tree[i].master_pending := pending_GrantData;
endrule;

rule "Ln_receive_AcquireBlock_NtoT_Branch_None_None"
    i > 1 &
    !IsUndefined(Tree[i].chanA[b1].opcode) &
    Tree[i].chanA[b1].opcode = AcquireBlock &
    Tree[i].chanA[b1].para = NtoT &
    Tree[i].cache.state = Branch &
    forall k: branchType do
        Tree[i].directory[k] = None
    endforall &
    IsUndefined(Tree[i].master_pending)
==>
begin
    Tree[j].chanA[b2].opcode := AcquirePerm;
    Tree[j].chanA[b2].para := BtoT;
    Tree[i].master_pending := pending_Grant;
endrule;
endalias;
endruleset;

-- Ln receive
-- from lower level
ruleset i : cacheId do
alias j: (i-2)/allBranchNum+1;
      b: i-allBranchNum*(j-1)-1 do
rule "Ln_receive_Grant"
    i > 1 &
    !IsUndefined(Tree[j].chanD[b].opcode) &
    Tree[j].chanD[b].opcode = Grant &
    Tree[j].chanD[b].para = toT
==>
begin
    Tree[i].cache.state := Tip;
    undefine Tree[j].chanD[b];
    undefine Tree[i].master_pending;
    Tree[j].chanE[b].opcode := GrantAck;
endrule;

rule "Ln_receive_GrantData_toB"
    i > 1 &
    !IsUndefined(Tree[j].chanD[b].opcode) &
    Tree[j].chanD[b].opcode = GrantData &
    Tree[j].chanD[b].para = toB
==>
begin
    Tree[i].cache.state := Branch;
    undefine Tree[j].chanD[b];
    undefine Tree[i].master_pending;
    Tree[j].chanE[b].opcode := GrantAck;
endrule;

rule "Ln_receive_GrantData_toT"
    i > 1 &
    !IsUndefined(Tree[j].chanD[b].opcode) &
    Tree[j].chanD[b].opcode = GrantData &
    Tree[j].chanD[b].para = toT
==>
begin
    Tree[i].cache.state := Tip;
    undefine Tree[j].chanD[b];
    undefine Tree[i].master_pending;
    Tree[j].chanE[b].opcode := GrantAck;
endrule;

rule "Ln_receive_ReleaseAck"
    i > 1 &
    !IsUndefined(Tree[j].chanD[b].opcode) &
    Tree[j].chanD[b].opcode = ReleaseAck
==>
begin
    undefine Tree[j].chanD[b];
    undefine Tree[i].master_pending;
endrule;

rule "Ln_receive_Probe_None_None_None"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[i].cache.state = None &
    forall k: branchType do
        Tree[i].directory[k] = None
    endforall &
    (IsUndefined(Tree[i].master_pending) |
    Tree[i].master_pending != pending_ReleaseAck)
==>
begin
    undefine Tree[j].chanB[b];
    Tree[j].chanC[b].opcode := ProbeAckData;
    Tree[j].chanC[b].para := NtoN;
endrule;

rule "Ln_receive_Probe_toN_None_Branch/Tip"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toN &
    Tree[i].cache.state = None &
    exists k: branchType do
        (Tree[i].directory[k] = Branch |
         Tree[i].directory[k] = Tip) &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k: branchType do
        if (Tree[i].directory[k] = Branch |
           Tree[i].directory[k] = Tip) &
           IsUndefined(Tree[i].slave_pending[k]) then
            Tree[i].chanB[k].opcode := Probe;
            Tree[i].chanB[k].para := toN;
            Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    end;
endrule;

rule "Ln_receive_Probe_toB_None_Branch/Tip"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toB &
    Tree[i].cache.state = None &
    exists k: branchType do
        (Tree[i].directory[k] = Branch |
         Tree[i].directory[k] = Tip) &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k: branchType do
        if (Tree[i].directory[k] = Branch |
           Tree[i].directory[k] = Tip) &
           IsUndefined(Tree[i].slave_pending[k]) then
            Tree[i].chanB[k].opcode := Probe;
            Tree[i].chanB[k].para := toB;
            Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    end;
endrule;

rule "Ln_receive_Probe_toN_Branch_None"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toN &
    Tree[i].cache.state = Branch & 
    forall k : branchType do
        Tree[i].directory[k] = None 
    endforall &
    (IsUndefined(Tree[i].master_pending) |
    Tree[i].master_pending != pending_ReleaseAck)
==>
begin
    undefine Tree[j].chanB[b];
    Tree[j].chanC[b].opcode := ProbeAckData;
    Tree[j].chanC[b].para := BtoN;
    Tree[i].cache.state := None;
endrule;

rule "Ln_receive_Probe_toN_Branch_Branch"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toN &
    Tree[i].cache.state = Branch & 
    exists k : branchType do
        Tree[i].directory[k] = Branch &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k : branchType do
        if  Tree[i].directory[k] = Branch &
            IsUndefined(Tree[i].slave_pending[k]) then
                Tree[i].chanB[k].opcode := Probe;
                Tree[i].chanB[k].para := toN;
                Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;

rule "Ln_receive_Probe_toN_Tip_None"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toN &
    Tree[i].cache.state = Tip & 
    forall k : branchType do
        Tree[i].directory[k] = None 
    endforall &
    (!IsUndefined(Tree[i].master_pending) ->
    Tree[i].master_pending != pending_ReleaseAck)
==>
begin
    undefine Tree[j].chanB[b];
    Tree[i].cache.state := None;
    Tree[j].chanC[b].para := TtoN;
    Tree[j].chanC[b].opcode := ProbeAckData;
    Tree[i].cache.state := None;
endrule;

rule "Ln_receive_Probe_toB_Branch"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toB &
    Tree[i].cache.state = Branch & 
    (!IsUndefined(Tree[i].master_pending) ->
    Tree[i].master_pending != pending_ReleaseAck)
==>
begin
    undefine Tree[j].chanB[b];
    Tree[j].chanC[b].para := BtoB;
    Tree[j].chanC[b].opcode := ProbeAckData;
endrule;

rule "Ln_receive_Probe_toB_None_Branch"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toB &
    Tree[i].cache.state = None & 
    exists k: branchType do
        Tree[i].directory[k] = Branch &
        IsUndefined(Tree[i].slave_pending[k])
    end
==>
begin
    for k : branchType do
        if  Tree[i].directory[k] = Branch &
            IsUndefined(Tree[i].slave_pending[k]) then 
                Tree[i].chanB[k].opcode := Probe;
                Tree[i].chanB[k].para := toB;
                Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;

rule "Ln_receive_Probe_toB_Tip"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toB &
    Tree[i].cache.state = Tip & 
    (!IsUndefined(Tree[i].master_pending) ->
    Tree[i].master_pending != pending_ReleaseAck)
==>
begin
    undefine Tree[j].chanB[b];
    Tree[i].cache.state := Branch;
    Tree[j].chanC[b].para := TtoB;
    Tree[j].chanC[b].opcode := ProbeAckData;
endrule;

rule "Ln_receive_Probe_toN_Trunk"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toN &
    Tree[i].cache.state = Trunk
==>
begin
    for k : branchType do
        if  Tree[i].directory[k] = Tip &
            IsUndefined(Tree[i].slave_pending[k]) then 
                Tree[i].chanB[k].opcode := Probe;
                Tree[i].chanB[k].para := toN;
                Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;

rule "Ln_receive_Probe_toB_Trunk"
    i > 1 &
    !IsUndefined(Tree[j].chanB[b].opcode) &
    Tree[j].chanB[b].opcode = Probe &
    Tree[j].chanB[b].para = toB &
    Tree[i].cache.state = Trunk
==>
begin
    for k : branchType do
        if  Tree[i].directory[k] = Tip &
            IsUndefined(Tree[i].slave_pending[k]) then 
                Tree[i].chanB[k].opcode := Probe;
                Tree[i].chanB[k].para := toB;
                Tree[i].slave_pending[k] := pending_ProbeAckData;
        endif;
    endfor;
endrule;
endalias;
endruleset;

-- Ln send msg
ruleset i : cacheId do
alias j: (i-2)/allBranchNum+1;
      b: i-allBranchNum*(j-1)-1 do
rule "Ln_send_Release_Branch_None"
    i > 1 &
    Tree[i].cache.state = Branch &
    forall k : branchType do
        Tree[i].directory[k] = None &
        IsUndefined(Tree[i].chanA[k].opcode)
    endforall &
    IsUndefined(Tree[i].master_pending) &
    IsUndefined(Tree[j].chanC[b].opcode)
==>
begin
    Tree[j].chanC[b].opcode := ReleaseData;
    Tree[j].chanC[b].para := BtoN;
    Tree[i].master_pending := pending_ReleaseAck;
    Tree[i].cache.state := None;
endrule;

rule "Ln_send_Release_Tip_None"
    i > 1 &
    Tree[i].cache.state = Tip &
    forall k : branchType do
        Tree[i].directory[k] = None &
        IsUndefined(Tree[i].chanA[k].opcode)
    endforall &
    IsUndefined(Tree[i].master_pending) &
    IsUndefined(Tree[j].chanC[b].opcode)
==>
begin
    Tree[j].chanC[b].para := TtoN;
    Tree[j].chanC[b].opcode := ReleaseData;
    Tree[i].master_pending := pending_ReleaseAck;
    Tree[i].cache.state := None;
endrule;

rule "Ln_send_Release_Tip_Branch"
    i > 1 &
    Tree[i].cache.state = Tip &
    exists k : branchType do
        Tree[i].directory[k] = Branch
    end &
    forall k : branchType do
        IsUndefined(Tree[i].chanA[k].opcode)
    endforall &
    IsUndefined(Tree[i].master_pending) &
    IsUndefined(Tree[j].chanC[b].opcode)
==>
begin
    Tree[j].chanC[b].para := TtoB;
    Tree[j].chanC[b].opcode := ReleaseData;
    Tree[i].master_pending := pending_ReleaseAck;
    Tree[i].cache.state := None;
endrule;
endalias;
endruleset;

ruleset i : cacheId do
rule "Ln_send_Release_Branch_Branch"
    Tree[i].cache.state = Branch &
    exists k : branchType do
        Tree[i].directory[k] = Branch
    end
==>
begin
    Tree[i].cache.state := None;
endrule;

rule "Ln_send_Release_Trunk_Tip"
    Tree[i].cache.state = Trunk
==>
begin
    Tree[i].cache.state := None;
endrule;
endruleset;

--special for l3
rule "L3_send_release"
    Tree[1].cache.state != None
==>
begin
    Tree[1].cache.state := None;
endrule;

ruleset b: branchType do
rule "L3_receive_AcquirePerm_Branch_x_x"
    !IsUndefined(Tree[1].chanA[b].opcode) &
    Tree[1].chanA[b].opcode = AcquirePerm &
    Tree[1].cache.state = Branch
==>
begin
    Tree[1].cache.state := Tip;
endrule;

rule "L3_receive_AcquirePerm_None_Branch_x"
    !IsUndefined(Tree[1].chanA[b].opcode) &
    Tree[1].chanA[b].opcode = AcquirePerm &
    Tree[1].cache.state = None &
    Tree[1].directory[b] = Branch
==>
begin
    Tree[1].cache.state := Tip;
endrule;

rule "Ln_receive_Acquire_None_None_None"
    !IsUndefined(Tree[1].chanA[b].opcode) &
    Tree[1].cache.state = None &
    forall k: branchType do
        Tree[1].directory[k] = None
    endforall
==>
begin
    Tree[1].cache.state := Tip;
endrule;

rule "Ln_receive_AcquireBlock_NtoT_Branch_None_None"
    !IsUndefined(Tree[1].chanA[b].opcode) &
    Tree[1].chanA[b].opcode = AcquireBlock &
    Tree[1].chanA[b].para = NtoT &
    Tree[1].cache.state = Branch &
    forall k: branchType do
        Tree[1].directory[k] = None
    endforall
==>
begin
    Tree[1].cache.state := Tip;
endrule;
endruleset;



invariant "test_reachable_state_177"
    !( Tree[1].cache.state = Tip & Tree[2].cache.state = None & Tree[4].cache.state = None & Tree[5].cache.state = None & Tree[3].cache.state = Branch & Tree[6].cache.state = None & Tree[7].cache.state = None );


