create sequence mroid_seq;

create table markov3
(
    id integer not null,
    mroid integer not null primary key default nextval('mroid_seq'),
    c0 text null,
    c1 text null,
    c2 text null,
    next text null,
    cnt integer not null
);

create index markov3P on markov3 (id, c0, c1, c2, next);

create table markov2
(
    id integer not null,
    mroid integer not null primary key default nextval('mroid_seq'),
    c0 text null,
    c1 text null,
    next text null,
    cnt integer not null
);

create index markov2P on markov2 (id, c0, c1, next);

create table markov1
(
    id integer not null,
    mroid integer not null primary key default nextval('mroid_seq'),
    c0 text null,
    next text null,
    cnt integer not null
);

create index markov1P on markov2 (id, c0, next);

create table trainstate
(
    id integer not null,
    c0 text null,
    c1 text null,
    c2 text null,
    c3 text null,
    remainder text null
);

create table markovconstruct
(
    id integer not null,
    mvcid integer not null primary key default nextval('mroid_seq'),
    c0 text null,
    c1 text null,
    c2 text null,
    depth integer not null default 3,
    data text not null default ''
);

create table markovresult
(
    id integer not null,
    mvcid integer not null primary key default nextval('mroid_seq'),
    result text not null
);

create view vtrainstep as
select
    1 as step;

create view vtrain as
select
    1 as id,
    cast('' as text) as data,
    1 as steps;

create view vautotrain as
select
    1 as steps;

create view vmarkovprobabilities as
select
    c.id as id,
    c.mvcid as mvcid,
    3 as depth,
    m.next as next
from markovconstruct as c
left join markov3 as m on coalesce(c.id,-1) = coalesce(m.id,-1)
                      and coalesce(c.c0,'') = coalesce(m.c0,'')
                      and coalesce(c.c1,'') = coalesce(m.c1,'')
                      and coalesce(c.c2,'') = coalesce(m.c2,''),
     seq16 as n
where n.b < coalesce(cnt, 1)
union all
select
    c.id as id,
    c.mvcid as mvcid,
    2 as depth,
    m.next as next
from markovconstruct as c
left join markov2 as m on coalesce(c.id,-1) = coalesce(m.id,-1)
                      and coalesce(c.c1,'') = coalesce(m.c0,'')
                      and coalesce(c.c2,'') = coalesce(m.c1,''),
     seq16 as n
where n.b < coalesce(cnt, 1)
union all
select
    c.id as id,
    c.mvcid as mvcid,
    1 as depth,
    m.next as next
from markovconstruct as c
left join markov1 as m on coalesce(c.id,-1) = coalesce(m.id,-1)
                      and coalesce(c.c2,'') = coalesce(m.c0,''),
     seq16 as n
where n.b < coalesce(cnt, 1)
;

create view vconstructstep as
select
    1 as step;

create view vautoconstruct as
select
    1 as steps;

create rule "replace_markov3" as
    on insert to "markov3"
 where exists(select 1
                from markov3
               where coalesce(id,-1) = coalesce(new.id,-1)
                 and coalesce(c0,'') = coalesce(new.c0,'')
                 and coalesce(c1,'') = coalesce(new.c1,'')
                 and coalesce(c2,'') = coalesce(new.c2,'')
                 and coalesce(next,'') = coalesce(new.next,''))
    do instead
      (update markov3
          set cnt = cnt + new.cnt
        where coalesce(id,-1) = coalesce(new.id,-1)
          and coalesce(c0,'') = coalesce(new.c0,'')
          and coalesce(c1,'') = coalesce(new.c1,'')
          and coalesce(c2,'') = coalesce(new.c2,'')
          and coalesce(next,'') = coalesce(new.next,''));

create rule "replace_markov2" as
    on insert to "markov2"
 where exists(select 1
                from markov2
               where coalesce(id,-1) = coalesce(new.id, -1)
                 and coalesce(c0,'') = coalesce(new.c0,'')
                 and coalesce(c1,'') = coalesce(new.c1,'')
                 and coalesce(next,'') = coalesce(new.next,''))
    do instead
      (update markov2
          set cnt = cnt + new.cnt
        where coalesce(id, -1) = coalesce(new.id, -1)
          and coalesce(c0,'') = coalesce(new.c0,'')
          and coalesce(c1,'') = coalesce(new.c1,'')
          and coalesce(next,'') = coalesce(new.next,''));

create rule "replace_markov1" as
    on insert to "markov1"
 where exists(select 1
                from markov1
               where coalesce(id,-1) = coalesce(new.id,-1)
                 and coalesce(c0,'') = coalesce(new.c0,'')
                 and coalesce(next,'') = coalesce(new.next,''))
    do instead
      (update markov1
          set cnt = cnt + new.cnt
        where coalesce(id,-1) = coalesce(new.id,-1)
          and coalesce(c0,'') = coalesce(new.c0,'')
          and coalesce(next,'') = coalesce(new.next,''));

create function markovtrainstep() returns trigger as $$
begin
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

    insert into markov3
        (id, c0, c1, c2, cnt, next)
        select s.id, s.c0, s.c1, s.c2, 1 as cnt, s.c3 as next
          from trainstate as s;

    insert into markov2
        (id, c0, c1, cnt, next)
        select s.id, s.c1 as c0, s.c2 as c1, 1 as cnt, s.c3 as next
          from trainstate as s;

    insert into markov1
        (id, c0, cnt, next)
        select s.id, s.c2 as c0, 1 as cnt, s.c3 as next
          from trainstate as s;

    delete from trainstate where c3 is null;

    return new;
end
$$ language plpgsql;

create trigger vtrainstepInsert instead of insert on vtrainstep
for each row execute procedure markovtrainstep();

create function train() returns trigger as $$
begin
    insert into trainstate
        (id, c0, c1, c2, remainder)
        values
        (new.id, null, null, null, lower(new.data));

    insert into vtrainstep (step) select b from seq8 where b < coalesce(new.steps, length(new.data));

    return new;
end;
$$ language plpgsql;

create trigger vtrainInsert instead of insert on vtrain
for each row execute procedure train();

create function autotrain() returns trigger as $$
begin
    insert into vtrainstep
        (step)
        select generate_series
          from generate_series
              (0, coalesce (new.steps, length((select remainder
                                                 from trainstate
                                                order by length(remainder) desc
                                                limit 1))));

    return new;
end;
$$ language plpgsql;

create trigger vautotrainInsert instead of insert on vautotrain
for each row execute procedure autotrain();

create function constructstep() returns trigger as $$
begin
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

    insert into markovresult
        (id, mvcid, result)
        select id, mvcid, data
          from markovconstruct
         where c2 is null;

    delete from markovconstruct where c2 is null;

    return new;
end;
$$ language plpgsql;

create trigger vconstructstepInsert instead of insert on vconstructstep
for each row execute procedure constructstep();

create function autoconstruct() returns trigger as $$
begin
    insert into vconstructstep
        (step)
        select generate_series
          from generate_series (0, coalesce(new.steps, 50));

    return new;
end;
$$ language plpgsql;

create trigger vautoconstructInsert instead of insert on vautoconstruct
for each row execute procedure autoconstruct();
