
-- First DDL migration, table creation.
drop table if exists items;
create table items (
	item_id INTEGER primary key,
	title text not null,
	contents text default ''
);


-- Optional DML migration, initial data.
insert into items (item_id, title, contents)
values 
(1, 'Nice and cool stuff', 'Hello there, this is a content full of nice and cool stuff.'),
(2, 'Just another boring title', null),
(3, 'How to make your dog happy', 'Sample content to make your dog happy, secret is attention.')
;


select * from items;

-- DDL/DML Migration, new fulltext search related columns 

alter table items add column text_lang text not null default 'english';
alter table items add column tsv tsvector;

create index tsv_index on items using gin(tsv);

update items set tsv = setweight(to_tsvector(text_lang::regconfig, title) , 'A') || 
						setweight(to_tsvector(text_lang::regconfig, coalesce(contents, '')), 'D');


-- Repeatable migration, fulltext search related procedures

drop trigger if exists items_tsvector_update on items;
drop function if exists items_search_trigger();

create function items_search_trigger() returns trigger as $$
begin
	new.tsv := 
		setweight(to_tsvector(new.text_lang::regconfig, new.title) , 'A') || 
		setweight(to_tsvector(new.text_lang::regconfig, coalesce(new.contents, '')), 'D');
	return new;
end
$$ language plpgsql;

create trigger items_tsvector_update before insert or update 
	on items for each row execute procedure items_search_trigger();


-- DML Migration, adding new rows


insert into items (item_id, title, contents, text_lang)
values 
(4, 'Mobile phones operative systems', 'There are several mobile phone operative systems such as Android, iOS and Tizen.', default),
(5, 'Android and cats', 'Definitely an android device was not designed for cats.', default),
(6, 'Los gatos son geniales', 'Los perros están ok, pero los gatos son muy cool!', 'spanish')
;



select title, contents from items 
	where tsv @@ plainto_tsquery (text_lang::regconfig, 'phone systems')
	offset 0 limit 1;

select title, contents from items 
	where tsv @@ plainto_tsquery (text_lang::regconfig, 'gato genial')
	offset 0 limit 1;

select title, contents from items 
	where tsv @@ plainto_tsquery (text_lang::regconfig, 'dog happy')
	offset 0 limit 1;

select title, contents, 
		ts_headline(text_lang::regconfig, title, 
			plainto_tsquery (text_lang::regconfig, 'cool')
		) as title_headline ,
		ts_headline(text_lang::regconfig, contents, 
			plainto_tsquery (text_lang::regconfig, 'cool')
		) as contents_headline 
	from items 
	where tsv @@ plainto_tsquery (text_lang::regconfig, 'cool')
	order by ts_rank_cd(tsv, plainto_tsquery (text_lang::regconfig, 'cool')) DESC
;


