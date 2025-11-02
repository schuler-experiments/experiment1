program taskmanager;
{$mode objfpc}{$H+}

uses
  sysutils,
  math,
  dateutils;

type
  tstringdynarray = array of string;
  tqworddynarray = array of qword;

  ttaskpriority = (tplow, tpmedium, tphigh, tpcritical);
  ttaskstatus = (tspending, tsinprogress, tscompleted, tsblocked);

  ttask = record
    id: qword;
    title: string;
    description: string;
    priority: ttaskpriority;
    status: ttaskstatus;
    duedate: tdatetime;
    createdat: tdatetime;
    updatedat: tdatetime;
    completedat: tdatetime;
    tags: tstringdynarray;
    dependencies: tqworddynarray;
    estimatedhours: double;
    actualhours: double;
    recurrenceintervaldays: integer;
  end;

  ttaskdynarray = array of ttask;

  ttasksummary = record
    total: qword;
    pending: qword;
    inprogress: qword;
    completed: qword;
    blocked: qword;
    overdue: qword;
  end;

  ttaskprogress = record
    totalestimated: double;
    totalactual: double;
    completedestimated: double;
    completedactual: double;
    averagecompletionhours: double;
    completedcount: qword;
    activecount: qword;
    overduecount: qword;
  end;

  ttaskmanager = class
  private
    ftasks: ttaskdynarray;
    function findindexbyid(const aid: qword): integer;
    function nexttaskid: qword;
    procedure setupdatedat(const aindex: integer);
    procedure copytags(var atarget: tstringdynarray; const asource: tstringdynarray);
    procedure copydependencies(var atarget: tqworddynarray; const asource: tqworddynarray);
    function tagexists(const atags: tstringdynarray; const atag: string): boolean;
    function istaskcompleted(const aid: qword): boolean;
    procedure cleardependencyreferences(const aid: qword);
  public
    constructor create;
    function addtask(const atitle, adescription: string; const apriority: ttaskpriority; const aduedate: tdatetime): ttask;
    function updatestatus(const aid: qword; const astatus: ttaskstatus): boolean;
    function updatepriority(const aid: qword; const apriority: ttaskpriority): boolean;
    function updatedescription(const aid: qword; const adescription: string): boolean;
    function removetask(const aid: qword): boolean;
    function gettaskcount: qword;
    function getalltasks: ttaskdynarray;
    function gettasksbystatus(const astatus: ttaskstatus): ttaskdynarray;
    function gettasksbypriority(const apriority: ttaskpriority): ttaskdynarray;
    function getoverduetasks(const areference: tdatetime): ttaskdynarray;
    function getsummaries(const areference: tdatetime): ttasksummary;
    function settasktags(const aid: qword; const atags: tstringdynarray): boolean;
    function addtasktag(const aid: qword; const atag: string): boolean;
    function removetasktag(const aid: qword; const atag: string): boolean;
    function setestimatedhours(const aid: qword; const ahours: double): boolean;
    function logactualhours(const aid: qword; const additionalhours: double): boolean;
    function setdependencies(const aid: qword; const adependencies: tqworddynarray): boolean;
    function setrecurrenceinterval(const aid: qword; const aintervaldays: integer): boolean;
    function generaterecurrences(const aid: qword; const acount: integer): ttaskdynarray;
    function gettasksbytag(const atag: string): ttaskdynarray;
    function gettasksduesoon(const areference: tdatetime; const adaywindow: integer): ttaskdynarray;
    function gettasksreadytostart: ttaskdynarray;
    function getprogresssnapshot(const areference: tdatetime): ttaskprogress;
  end;

function ttaskmanager.findindexbyid(const aid: qword): integer;
var
  i: integer;
  len: integer;
begin
  result := -1;
  len := length(ftasks);
  for i := 0 to len - 1 do
    begin
      if ftasks[i].id = aid then
        begin
          result := i;
          exit;
        end;
    end;
end;

function ttaskmanager.nexttaskid: qword;
var
  i: integer;
  len: integer;
  maxid: qword;
begin
  maxid := 0;
  len := length(ftasks);
  for i := 0 to len - 1 do
    begin
      if ftasks[i].id > maxid then
        begin
          maxid := ftasks[i].id;
        end;
    end;
  result := maxid + 1;
end;

procedure ttaskmanager.setupdatedat(const aindex: integer);
begin
  if (aindex >= 0) and (aindex < length(ftasks)) then
    begin
      ftasks[aindex].updatedat := now;
    end;
end;

procedure ttaskmanager.copytags(var atarget: tstringdynarray; const asource: tstringdynarray);
var
  len: integer;
  i: integer;
begin
  len := length(asource);
  setlength(atarget, len);
  for i := 0 to len - 1 do
    begin
      atarget[i] := asource[i];
    end;
end;

procedure ttaskmanager.copydependencies(var atarget: tqworddynarray; const asource: tqworddynarray);
var
  len: integer;
  i: integer;
begin
  len := length(asource);
  setlength(atarget, len);
  for i := 0 to len - 1 do
    begin
      atarget[i] := asource[i];
    end;
end;

function ttaskmanager.tagexists(const atags: tstringdynarray; const atag: string): boolean;
var
  i: integer;
  len: integer;
begin
  result := false;
  len := length(atags);
  for i := 0 to len - 1 do
    begin
      if ansicomparetext(atags[i], atag) = 0 then
        begin
          exit(true);
        end;
    end;
end;

function ttaskmanager.istaskcompleted(const aid: qword): boolean;
var
  idx: integer;
begin
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      exit(ftasks[idx].status = tscompleted);
    end;
  result := false;
end;

procedure ttaskmanager.cleardependencyreferences(const aid: qword);
var
  taskindex: integer;
  depindex: integer;
  destindex: integer;
  len: integer;
  depcount: integer;
begin
  len := length(ftasks);
  for taskindex := 0 to len - 1 do
    begin
      depcount := length(ftasks[taskindex].dependencies);
      destindex := 0;
      for depindex := 0 to depcount - 1 do
        begin
          if ftasks[taskindex].dependencies[depindex] <> aid then
            begin
              ftasks[taskindex].dependencies[destindex] := ftasks[taskindex].dependencies[depindex];
              inc(destindex);
            end;
        end;
      if destindex <> depcount then
        begin
          setlength(ftasks[taskindex].dependencies, destindex);
        end;
    end;
end;

constructor ttaskmanager.create;
begin
  inherited create;
  setlength(ftasks, 0);
end;

function ttaskmanager.addtask(const atitle, adescription: string; const apriority: ttaskpriority; const aduedate: tdatetime): ttask;
var
  newtask: ttask;
  len: integer;
  newid: qword;
begin
  newid := nexttaskid;
  newtask.id := newid;
  newtask.title := atitle;
  newtask.description := adescription;
  newtask.priority := apriority;
  newtask.status := tspending;
  newtask.duedate := aduedate;
  newtask.createdat := now;
  newtask.updatedat := newtask.createdat;
  newtask.completedat := 0;
  setlength(newtask.tags, 0);
  setlength(newtask.dependencies, 0);
  newtask.estimatedhours := 0.0;
  newtask.actualhours := 0.0;
  newtask.recurrenceintervaldays := 0;
  len := length(ftasks);
  setlength(ftasks, len + 1);
  ftasks[len] := newtask;
  result := newtask;
end;

function ttaskmanager.updatestatus(const aid: qword; const astatus: ttaskstatus): boolean;
var
  idx: integer;
begin
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      ftasks[idx].status := astatus;
      if astatus = tscompleted then
        begin
          ftasks[idx].completedat := now;
        end
      else
        begin
          ftasks[idx].completedat := 0;
        end;
      setupdatedat(idx);
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.updatepriority(const aid: qword; const apriority: ttaskpriority): boolean;
var
  idx: integer;
begin
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      ftasks[idx].priority := apriority;
      setupdatedat(idx);
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.updatedescription(const aid: qword; const adescription: string): boolean;
var
  idx: integer;
begin
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      ftasks[idx].description := adescription;
      setupdatedat(idx);
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.removetask(const aid: qword): boolean;
var
  idx: integer;
  i: integer;
  lastindex: integer;
begin
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      lastindex := high(ftasks);
      for i := idx to lastindex - 1 do
        begin
          ftasks[i] := ftasks[i + 1];
        end;
      if length(ftasks) > 0 then
        begin
          setlength(ftasks, length(ftasks) - 1);
        end;
      cleardependencyreferences(aid);
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.gettaskcount: qword;
begin
  result := length(ftasks);
end;

function ttaskmanager.getalltasks: ttaskdynarray;
var
  i: integer;
  len: integer;
begin
  result := nil;
  len := length(ftasks);
  setlength(result, len);
  for i := 0 to len - 1 do
    begin
      result[i] := ftasks[i];
    end;
end;

function ttaskmanager.gettasksbystatus(const astatus: ttaskstatus): ttaskdynarray;
var
  i: integer;
  len: integer;
  count: integer;
begin
  result := nil;
  count := 0;
  len := length(ftasks);
  setlength(result, 0);
  for i := 0 to len - 1 do
    begin
      if ftasks[i].status = astatus then
        begin
          setlength(result, count + 1);
          result[count] := ftasks[i];
          inc(count);
        end;
    end;
end;

function ttaskmanager.gettasksbypriority(const apriority: ttaskpriority): ttaskdynarray;
var
  i: integer;
  len: integer;
  count: integer;
begin
  result := nil;
  count := 0;
  len := length(ftasks);
  setlength(result, 0);
  for i := 0 to len - 1 do
    begin
      if ftasks[i].priority = apriority then
        begin
          setlength(result, count + 1);
          result[count] := ftasks[i];
          inc(count);
        end;
    end;
end;

function ttaskmanager.getoverduetasks(const areference: tdatetime): ttaskdynarray;
var
  i: integer;
  len: integer;
  count: integer;
begin
  result := nil;
  count := 0;
  len := length(ftasks);
  setlength(result, 0);
  for i := 0 to len - 1 do
    begin
      if (ftasks[i].duedate < areference) and (ftasks[i].status <> tscompleted) then
        begin
          setlength(result, count + 1);
          result[count] := ftasks[i];
          inc(count);
        end;
    end;
end;

function ttaskmanager.getsummaries(const areference: tdatetime): ttasksummary;
var
  i: integer;
  len: integer;
begin
  result.total := 0;
  result.pending := 0;
  result.inprogress := 0;
  result.completed := 0;
  result.blocked := 0;
  result.overdue := 0;
  len := length(ftasks);
  for i := 0 to len - 1 do
    begin
      inc(result.total);
      case ftasks[i].status of
        tspending:
          inc(result.pending);
        tsinprogress:
          inc(result.inprogress);
        tscompleted:
          inc(result.completed);
        tsblocked:
          inc(result.blocked);
      end;
      if (ftasks[i].duedate < areference) and (ftasks[i].status <> tscompleted) then
        begin
          inc(result.overdue);
        end;
    end;
end;

function ttaskmanager.settasktags(const aid: qword; const atags: tstringdynarray): boolean;
var
  idx: integer;
begin
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      copytags(ftasks[idx].tags, atags);
      setupdatedat(idx);
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.addtasktag(const aid: qword; const atag: string): boolean;
var
  idx: integer;
  len: integer;
begin
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      if not tagexists(ftasks[idx].tags, atag) then
        begin
          len := length(ftasks[idx].tags);
          setlength(ftasks[idx].tags, len + 1);
          ftasks[idx].tags[len] := atag;
          setupdatedat(idx);
        end;
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.removetasktag(const aid: qword; const atag: string): boolean;
var
  idx: integer;
  i: integer;
  len: integer;
  found: boolean;
  dest: integer;
begin
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      len := length(ftasks[idx].tags);
      found := false;
      dest := 0;
      for i := 0 to len - 1 do
        begin
          if (not found) and (ansicomparetext(ftasks[idx].tags[i], atag) = 0) then
            begin
              found := true;
            end
          else
            begin
              ftasks[idx].tags[dest] := ftasks[idx].tags[i];
              inc(dest);
            end;
        end;
      if found then
        begin
          setlength(ftasks[idx].tags, dest);
          setupdatedat(idx);
          exit(true);
        end;
    end;
  result := false;
end;

function ttaskmanager.setestimatedhours(const aid: qword; const ahours: double): boolean;
var
  idx: integer;
begin
  if ahours < 0.0 then
    begin
      result := false;
      exit;
    end;
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      ftasks[idx].estimatedhours := ahours;
      setupdatedat(idx);
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.logactualhours(const aid: qword; const additionalhours: double): boolean;
var
  idx: integer;
begin
  if additionalhours < 0.0 then
    begin
      result := false;
      exit;
    end;
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      ftasks[idx].actualhours := ftasks[idx].actualhours + additionalhours;
      setupdatedat(idx);
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.setdependencies(const aid: qword; const adependencies: tqworddynarray): boolean;
var
  idx: integer;
  i: integer;
  len: integer;
  unique: tqworddynarray;
  count: integer;
  isduplicate: boolean;
  j: integer;
begin
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      setlength(unique, 0);
      count := 0;
      len := length(adependencies);
      for i := 0 to len - 1 do
        begin
          if adependencies[i] = aid then
            begin
              continue;
            end;
          isduplicate := false;
          for j := 0 to count - 1 do
            begin
              if unique[j] = adependencies[i] then
                begin
                  isduplicate := true;
                  break;
                end;
            end;
          if not isduplicate then
            begin
              setlength(unique, count + 1);
              unique[count] := adependencies[i];
              inc(count);
            end;
        end;
      copydependencies(ftasks[idx].dependencies, unique);
      setupdatedat(idx);
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.setrecurrenceinterval(const aid: qword; const aintervaldays: integer): boolean;
var
  idx: integer;
begin
  if aintervaldays < 0 then
    begin
      result := false;
      exit;
    end;
  idx := findindexbyid(aid);
  if idx <> -1 then
    begin
      ftasks[idx].recurrenceintervaldays := aintervaldays;
      setupdatedat(idx);
      exit(true);
    end;
  result := false;
end;

function ttaskmanager.generaterecurrences(const aid: qword; const acount: integer): ttaskdynarray;
var
  idx: integer;
  base: ttask;
  i: integer;
  newdue: tdatetime;
  createdtask: ttask;
  copies: ttaskdynarray;
  copycount: integer;
begin
  result := nil;
  setlength(result, 0);
  if acount <= 0 then
    begin
      exit;
    end;
  idx := findindexbyid(aid);
  if idx = -1 then
    begin
      exit;
    end;
  base := ftasks[idx];
  if base.recurrenceintervaldays <= 0 then
    begin
      exit;
    end;
  setlength(copies, 0);
  copycount := 0;
  for i := 1 to acount do
    begin
      newdue := incday(base.duedate, base.recurrenceintervaldays * i);
      createdtask := addtask(base.title, base.description, base.priority, newdue);
      setestimatedhours(createdtask.id, base.estimatedhours);
      settasktags(createdtask.id, base.tags);
      setdependencies(createdtask.id, base.dependencies);
      setrecurrenceinterval(createdtask.id, base.recurrenceintervaldays);
      createdtask := ftasks[findindexbyid(createdtask.id)];
      setlength(copies, copycount + 1);
      copies[copycount] := createdtask;
      inc(copycount);
    end;
  result := copies;
end;

function ttaskmanager.gettasksbytag(const atag: string): ttaskdynarray;
var
  i: integer;
  len: integer;
  count: integer;
begin
  result := nil;
  count := 0;
  len := length(ftasks);
  setlength(result, 0);
  for i := 0 to len - 1 do
    begin
      if tagexists(ftasks[i].tags, atag) then
        begin
          setlength(result, count + 1);
          result[count] := ftasks[i];
          inc(count);
        end;
    end;
end;

function ttaskmanager.gettasksduesoon(const areference: tdatetime; const adaywindow: integer): ttaskdynarray;
var
  i: integer;
  len: integer;
  count: integer;
  enddate: tdatetime;
  windowdays: integer;
begin
  result := nil;
  count := 0;
  len := length(ftasks);
  setlength(result, 0);
  windowdays := adaywindow;
  if windowdays < 0 then
    begin
      windowdays := 0;
    end;
  enddate := incday(areference, windowdays);
  for i := 0 to len - 1 do
    begin
      if (ftasks[i].duedate >= areference) and (ftasks[i].duedate <= enddate) then
        begin
          setlength(result, count + 1);
          result[count] := ftasks[i];
          inc(count);
        end;
    end;
end;

function ttaskmanager.gettasksreadytostart: ttaskdynarray;
var
  i: integer;
  count: integer;
  depcount: integer;
  depindex: integer;
  ready: boolean;
  taskref: ttask;
  len: integer;
begin
  result := nil;
  count := 0;
  len := length(ftasks);
  setlength(result, 0);
  for i := 0 to len - 1 do
    begin
      taskref := ftasks[i];
      if taskref.status <> tspending then
        begin
          continue;
        end;
      depcount := length(taskref.dependencies);
      ready := true;
      for depindex := 0 to depcount - 1 do
        begin
          if not istaskcompleted(taskref.dependencies[depindex]) then
            begin
              ready := false;
              break;
            end;
        end;
      if ready then
        begin
          setlength(result, count + 1);
          result[count] := taskref;
          inc(count);
        end;
    end;
end;

function ttaskmanager.getprogresssnapshot(const areference: tdatetime): ttaskprogress;
var
  i: integer;
  len: integer;
  cyclehours: double;
  cyclecount: integer;
  completedhours: double;
  reference: tdatetime;
begin
  result.totalestimated := 0.0;
  result.totalactual := 0.0;
  result.completedestimated := 0.0;
  result.completedactual := 0.0;
  result.averagecompletionhours := 0.0;
  result.completedcount := 0;
  result.activecount := 0;
  result.overduecount := 0;
  len := length(ftasks);
  cyclehours := 0.0;
  cyclecount := 0;
  reference := areference;
  for i := 0 to len - 1 do
    begin
      result.totalestimated := result.totalestimated + ftasks[i].estimatedhours;
      result.totalactual := result.totalactual + ftasks[i].actualhours;
      if ftasks[i].status = tscompleted then
        begin
          inc(result.completedcount);
          result.completedestimated := result.completedestimated + ftasks[i].estimatedhours;
          result.completedactual := result.completedactual + ftasks[i].actualhours;
          if ftasks[i].completedat > 0 then
            begin
              completedhours := (ftasks[i].completedat - ftasks[i].createdat) * 24.0;
              cyclehours := cyclehours + completedhours;
              inc(cyclecount);
            end;
        end
      else
        begin
          inc(result.activecount);
        end;
      if (ftasks[i].duedate < reference) and (ftasks[i].status <> tscompleted) then
        begin
          inc(result.overduecount);
        end;
    end;
  if cyclecount > 0 then
    begin
      result.averagecompletionhours := cyclehours / cyclecount;
    end;
end;

procedure printtasks(const alabel: string; const atasks: ttaskdynarray);
var
  i: integer;
  taskinfo: string;
  len: integer;

  function joinstrings(const items: tstringdynarray): string;
  var
    j: integer;
    count: integer;
    builder: string;
  begin
    count := length(items);
    builder := '';
    for j := 0 to count - 1 do
      begin
        if j > 0 then
          begin
            builder := builder + ', ';
          end;
        builder := builder + items[j];
      end;
    result := builder;
  end;

  function joinintegers(const items: tqworddynarray): string;
  var
    j: integer;
    count: integer;
    builder: string;
  begin
    count := length(items);
    builder := '';
    for j := 0 to count - 1 do
      begin
        if j > 0 then
          begin
            builder := builder + ', ';
          end;
        builder := builder + inttostr(items[j]);
      end;
    result := builder;
  end;

begin
  writeln('--- ', alabel, ' ---');
  len := length(atasks);
  if len = 0 then
    begin
      writeln('no tasks');
      exit;
    end;
  for i := 0 to len - 1 do
    begin
      taskinfo := format('id=%d title="%s" status=%d priority=%d due=%s est=%.2f act=%.2f recint=%d',
        [atasks[i].id,
         atasks[i].title,
         ord(atasks[i].status),
         ord(atasks[i].priority),
         datetostr(atasks[i].duedate),
         atasks[i].estimatedhours,
         atasks[i].actualhours,
         atasks[i].recurrenceintervaldays]);
      writeln(taskinfo);
      writeln('  tags: [', joinstrings(atasks[i].tags), ']');
      writeln('  dependencies: [', joinintegers(atasks[i].dependencies), ']');
      if atasks[i].completedat > 0 then
        begin
          writeln('  completed at ', datetimetostr(atasks[i].completedat));
        end;
    end;
end;

procedure self_test;
var
  manager: ttaskmanager;
  task1: ttask;
  task2: ttask;
  task3: ttask;
  tasks: ttaskdynarray;
  statusgroup: ttaskdynarray;
  prioritygroup: ttaskdynarray;
  overduelist: ttaskdynarray;
  readiness: ttaskdynarray;
  duesoon: ttaskdynarray;
  tagmatches: ttaskdynarray;
  recurrences: ttaskdynarray;
  summary: ttasksummary;
  progress: ttaskprogress;
  designtags: tstringdynarray;
  implementationtags: tstringdynarray;
  documentationtags: tstringdynarray;
  dependencies: tqworddynarray;
  i: integer;
  len: integer;
begin
  manager := ttaskmanager.create;
  try
    task1 := manager.addtask('design module', 'design task manager module', tphigh, encodedate(2024, 4, 15));
    task2 := manager.addtask('implement module', 'implement classes and logic', tpcritical, encodedate(2024, 4, 20));
    task3 := manager.addtask('write documentation', 'document task manager usage', tpmedium, encodedate(2024, 4, 25));

    setlength(designtags, 2);
    designtags[0] := 'architecture';
    designtags[1] := 'planning';
    manager.settasktags(task1.id, designtags);
    manager.addtasktag(task1.id, 'documentation');
    manager.removetasktag(task1.id, 'documentation');

    setlength(implementationtags, 3);
    implementationtags[0] := 'backend';
    implementationtags[1] := 'critical';
    implementationtags[2] := 'automation';
    manager.settasktags(task2.id, implementationtags);
    manager.addtasktag(task2.id, 'review');

    setlength(documentationtags, 2);
    documentationtags[0] := 'knowledge';
    documentationtags[1] := 'enablement';
    manager.settasktags(task3.id, documentationtags);

    manager.setestimatedhours(task1.id, 12.0);
    manager.setestimatedhours(task2.id, 24.0);
    manager.setestimatedhours(task3.id, 6.0);

    manager.logactualhours(task2.id, 5.5);
    manager.logactualhours(task3.id, 2.0);

    setlength(dependencies, 1);
    dependencies[0] := task1.id;
    manager.setdependencies(task2.id, dependencies);
    setlength(dependencies, 2);
    dependencies[0] := task1.id;
    dependencies[1] := task2.id;
    manager.setdependencies(task3.id, dependencies);

    manager.setrecurrenceinterval(task3.id, 7);
    recurrences := manager.generaterecurrences(task3.id, 2);
    printtasks('generated recurrences', recurrences);

    manager.updatestatus(task2.id, tsinprogress);
    manager.updatestatus(task3.id, tscompleted);
    manager.logactualhours(task3.id, 3.5);
    manager.updatedescription(task1.id, 'refine the architecture and document decisions');
    manager.updatepriority(task1.id, tpcritical);

    manager.removetask(task1.id + 10);

    tasks := manager.getalltasks;
    printtasks('all tasks', tasks);

    statusgroup := manager.gettasksbystatus(tscompleted);
    printtasks('completed tasks', statusgroup);

    prioritygroup := manager.gettasksbypriority(tpcritical);
    printtasks('critical priority tasks', prioritygroup);

    overduelist := manager.getoverduetasks(encodedate(2024, 4, 22));
    printtasks('overdue tasks', overduelist);

    readiness := manager.gettasksreadytostart;
    printtasks('ready to start tasks', readiness);

    duesoon := manager.gettasksduesoon(encodedate(2024, 4, 16), 5);
    printtasks('tasks due soon', duesoon);

    tagmatches := manager.gettasksbytag('critical');
    printtasks('tasks tagged "critical"', tagmatches);

    summary := manager.getsummaries(encodedate(2024, 4, 22));
    writeln('summary total=', summary.total);
    writeln('summary pending=', summary.pending);
    writeln('summary in progress=', summary.inprogress);
    writeln('summary completed=', summary.completed);
    writeln('summary blocked=', summary.blocked);
    writeln('summary overdue=', summary.overdue);

    progress := manager.getprogresssnapshot(encodedate(2024, 4, 22));
    writeln('progress total estimated=', formatfloat('0.00', progress.totalestimated));
    writeln('progress total actual=', formatfloat('0.00', progress.totalactual));
    writeln('progress completed estimated=', formatfloat('0.00', progress.completedestimated));
    writeln('progress completed actual=', formatfloat('0.00', progress.completedactual));
    writeln('progress average completion hours=', formatfloat('0.00', progress.averagecompletionhours));
    writeln('progress completed count=', progress.completedcount);
    writeln('progress active count=', progress.activecount);
    writeln('progress overdue count=', progress.overduecount);

    len := length(tasks);
    if len > 0 then
      begin
        for i := 0 to len - 1 do
          begin
            writeln('task ', tasks[i].id, ' last updated at ', datetimetostr(tasks[i].updatedat));
          end;
      end;
  finally
    manager.free;
  end;
end;

begin
  self_test;
end.

