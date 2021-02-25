-- Analysis into cohorts and following each batch of economists

-- Find a cohort of economist, for example in 2005, that is the first year they publish and not the only year they publish

select author_url, paper_url, year, first_name, last_name from (
	with author_paper_year as (
		select *
		from clean_author_paper cap 
		left join clean_paper_details using (paper_url) )
	select distinct paper_url, author_url , year, 
					max(year) over (partition by author_url) max_year,
					min(year) over (partition by author_url) min_year
	from author_paper_year) t
left join author_details using (author_url)
where t.min_year = 2005 and t.max_year > 2015
order by t.author_url, t.year;