create table markov3
(
    id integer not null,
    mroid integer not null primary key,
    c0 text null,
    c1 text null,
    c2 text null,
    next text null,
    cnt integer not null
);

create unique index markov3P on markov3 (id, c0, c1, c2, next);

create table markov2
(
    id integer not null,
    mroid integer not null primary key,
    c0 text null,
    c1 text null,
    next text null,
    cnt integer not null
);

create unique index markov2P on markov2 (id, c0, c1, next);

create table markov1
(
    id integer not null,
    mroid integer not null primary key,
    c0 text null,
    next text null,
    cnt integer not null
);

create unique index markov1P on markov2 (id, c0, next);

create table trainstate
(
    id integer not null,
    c0 text null,
    c1 text null,
    c2 text null,
    c3 text null,
    remainder text null,

    foreign key (id) references markov3(id)
);

create table markovconstruct
(
    id integer not null,
    mvcid integer not null primary key,
    c0 text null,
    c1 text null,
    c2 text null,
    depth integer not null default 3,
    data text not null default '',

    foreign key (id) references markov3(id)
);

create table markovresult
(
    id integer not null,
    mvcid integer not null primary key,
    result text not null,

    foreign key (id) references markov3(id)
);

create view vtrainstep as
select
    null as step;

create view vtrain as
select
    null as id,
    null as data,
    null as steps;

create view vautotrain as
select
    null as steps;

create view vmarkovprobabilities as
select
    c.id as id,
    c.mvcid as mvcid,
    3 as depth,
    m.next as next
from markovconstruct as c
left join markov3 as m on c.id is m.id and c.c0 is m.c0 and c.c1 is m.c1 and c.c2 is m.c2,
     seq16 as n
where n.b < coalesce(cnt, 1)
union all
select
    c.id as id,
    c.mvcid as mvcid,
    2 as depth,
    m.next as next
from markovconstruct as c
left join markov2 as m on c.id is m.id and c.c1 is m.c0 and c.c2 is m.c1,
     seq16 as n
where n.b < coalesce(cnt, 1)
union all
select
    c.id as id,
    c.mvcid as mvcid,
    1 as depth,
    m.next as next
from markovconstruct as c
left join markov1 as m on c.id is m.id and c.c2 is m.c0,
     seq16 as n
where n.b < coalesce(cnt, 1)
;

create view vconstructstep as
select
    null as step;

create view vautoconstruct as
select
    null as steps;

create trigger vtrainstepInsert instead of insert on vtrainstep
for each row begin
    update trainstate
       set c0 = c1,
           c1 = c2,
           c2 = c3,
           c3 = substr(remainder, 1, 1),
           remainder = substr(remainder, 2);

    update trainstate set c0 = null where c0 = '';
    update trainstate set c1 = null where c1 = '';
    update trainstate set c2 = null where c2 = '';
    update trainstate set c3 = null where c3 = '';
    update trainstate set remainder = null where remainder = '';

    update markov3
       set cnt = cnt + 1
     where mroid in (select mroid
                       from trainstate as s, markov3 as m
                      where m.id is s.id and m.c0 is s.c0 and m.c1 is s.c1 and m.c2 is s.c2 and m.next is s.c3);

    update markov2
       set cnt = cnt + 1
     where mroid in (select mroid
                       from trainstate as s, markov2 as m
                      where m.id is s.id and m.c0 is s.c1 and m.c1 is s.c2 and m.next is s.c3);

    update markov1
       set cnt = cnt + 1
     where mroid in (select mroid
                       from trainstate as s, markov2 as m
                      where m.id is s.id and m.c0 is s.c2 and m.next is s.c3);

    insert or replace into markov3
        (id, c0, c1, c2, cnt, next)
        select s.id, s.c0, s.c1, s.c2, 1 as cnt, s.c3 as next
          from trainstate as s
          left join markov3 as m on m.id is s.id and m.c0 is s.c0 and m.c1 is s.c1 and m.c2 is s.c2 and m.next is s.c3
         where m.cnt is null;

    insert or replace into markov2
        (id, c0, c1, cnt, next)
        select s.id, s.c1 as c0, s.c2 as c1, 1 as cnt, s.c3 as next
          from trainstate as s
          left join markov2 as m on m.id is s.id and m.c0 is s.c1 and m.c1 is s.c2 and m.next is s.c3
         where m.cnt is null;

    insert or replace into markov1
        (id, c0, cnt, next)
        select s.id, s.c2 as c0, 1 as cnt, s.c3 as next
          from trainstate as s
          left join markov1 as m on m.id is s.id and m.c0 is s.c2 and m.next is s.c3
         where m.cnt is null;

    delete from trainstate where c3 is null;
end;

create trigger vtrainInsert instead of insert on vtrain
for each row begin
    insert into trainstate
        (id, c0, c1, c2, remainder)
        values
        (new.id, null, null, null, lower(new.data));

    insert into vtrainstep (step) select b from seq8 where b < coalesce(new.steps, length(new.data));
end;

create trigger vautotrainInsert instead of insert on vautotrain
for each row begin
    insert into vtrainstep
        (step)
        select b
          from seq8
         where b < coalesce(new.steps, length((select remainder
                                                 from trainstate
                                                order by length(remainder) desc
                                                limit 1)));
end;

create trigger vconstructstepInsert instead of insert on vconstructstep
for each row begin
    update markovconstruct
       set c0 = c1,
           c1 = c2,
           c2 = (select next
                   from vmarkovprobabilities as p
                  where p.mvcid = markovconstruct.mvcid
                    and p.depth = markovconstruct.depth
                  order by random()
                  limit 1)
     where c2 is not null
        or (c0 is null and c1 is null and c2 is null);

    update markovconstruct
       set data = data || coalesce(c2, '');

    insert or replace into markovresult
        (id, mvcid, result)
        select id, mvcid, data
          from markovconstruct
         where c2 is null;

    delete from markovconstruct where c2 is null;
end;

create trigger vautoconstructInsert instead of insert on vautoconstruct
for each row begin
    insert into vconstructstep
        (step)
        select b
          from seq8
         where b < coalesce(new.steps, 50);
end;
