-- Goal of this script is to minimise the database so that it can be imported into Python for analysis

-- 1. There are some names in author_paper that are irregular - we need to clean it with author_urls. Get a table with just author_url and paper_url

-- a) Clean up the author_paper 
	-- Remove rows that have authors start with a symbol
	-- Remove . in first names

-- b) author_url table should create a new column with first_name with just the first letter
-- c) merge both tables together
-- USING COMMON TABLE EXPRESSION

create temp table temp_author_paper as (
	with ap as(
		select paper_url, replace(first_name, '.','') as first_name, last_name, left(first_name,1) as first_letter
		from author_paper
		where first_name ~ '^\w'),
	au as(
		select first_name, last_name, author_url, left(first_name,1) as first_letter
		from author_urls)
	select ap.first_name as first_name, ap.last_name as last_name, ap.paper_url as paper_url, 
		case 
			when au1.author_url is null and au2.author_url is not null then au2.author_url
			when au2.author_url is null and au1.author_url is not null then au1.author_url
			when au1.author_url is null and au2.author_url is null then null 
			when au1.author_url is not null and au2.author_url is not null then au1.author_url
		end matched_author_url
	from ap
	left join au as au1 on ap.first_name = au1.first_name and ap.last_name = au1.last_name
	left join au as au2 on ap.first_letter = au2.first_letter and ap.last_name = au2.last_name
);

create table clean_author_paper as (
	select first_name, last_name, paper_url, matched_author_url as author_url
	from temp_author_paper
	where matched_author_url is not null
);

-- Do some checks on how much we lost due to matching issues

select count(distinct(author_url))
from clean_author_paper;
select count(distinct(paper_url))
from clean_author_paper;
select count(distinct(paper_url)) 
from paper_details; 

drop table if exists temp_author_paper;

-- paper details change year to numeric
create table clean_paper_details as(
	select paper_url, paper, year::integer
	from paper_details
	where year != 'None'
);

select count(distinct(paper_url)) 
from clean_paper_details; 
