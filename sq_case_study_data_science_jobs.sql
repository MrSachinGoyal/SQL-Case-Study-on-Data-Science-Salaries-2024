-- You're a Compensation analyst employed by a multinational corporation. Your Assignment is to Pinpoint Countries who give work fully remotely, 
-- for the title 'managers’ Paying salaries Exceeding $90,000 USD

SELECT 
	DISTINCT(company_location) AS country
FROM 
	salaries
WHERE 
	(remote_ratio = 100) 
	AND (job_title LIKE '%%Manager%%')
	AND (salary_in_usd > 90000);
  
-- AS a remote work advocate Working for a progressive HR tech startup who place their freshers’ clients in large tech firms. You're tasked with 
-- Identifying top 5 Country Having greatest count of large (company size) number of companies.

WITH large_companies AS (
SELECT 
	company_location AS country,
	COUNT(company_size) AS count_large_companies,
	RANK() OVER(ORDER BY COUNT(company_size) DESC) AS rank_based_on_num_large_companies
FROM 
	salaries
WHERE 
	company_size = 'L'
GROUP BY 
	company_location
)

SELECT 
	country, 
	count_large_companies
FROM 
	large_companies
WHERE 
	rank_based_on_num_large_companies <= 5;
  
-- Picture yourself AS a data scientist Working for a workforce management platform. Your objective is to calculate the percentage of employees 
-- who enjoy fully remote roles WITH salaries Exceeding $100,000 USD, Shedding light ON the attractiveness of high-paying remote positions IN today's
-- job market.

SELECT
    (100 * COUNT(*)) / (SELECT COUNT(*) AS total_emp FROM salaries) AS emp_percentage
FROM 
	salaries
WHERE 
	(remote_ratio = 100)
    AND (salary_in_usd > 100000);
    
-- Imagine you're a data analyst Working for a global recruitment agency. Your Task is to identify the Locations where entry-level average salaries 
-- exceed the average salary for that job title IN market for entry level, helping your agency guide candidates towards lucrative opportunities.

WITH avg_salaries AS (
SELECT 
    company_location, 
    job_title, 
    COALESCE(ROUND(AVG(CASE WHEN experience_level = 'EN' THEN salary_in_usd ELSE NULL END)), 2) AS entry_level_avg_salary_in_usd,
    ROUND((AVG(salary_in_usd)), 2) AS avg_salary_in_usd
FROM 
	salaries
GROUP BY 
	company_location, 
	job_title
)

SELECT * 
FROM 
	avg_salaries
WHERE 
	entry_level_avg_salary_in_usd > avg_salary_in_usd;

-- You've been hired by a big HR Consultancy to look at how much people get paid in different Countries. Your job is to Find out for each job title 
-- which Country pays the maximum average salary. This helps you to place your candidates in those countries

WITH country_avg_salaries AS (
SELECT 
    company_location AS country,  
    job_title,
    AVG(salary_in_usd) AS avg_salary_in_usd,
    RANK() OVER(PARTITION BY job_title ORDER BY AVG(salary_in_usd) DESC) AS avg_salary_rank
FROM 
	salaries
GROUP BY 
	company_location, 
	job_title
)

SELECT 
    country,
    job_title,
    avg_salary_in_usd
FROM 
	country_avg_salaries
WHERE 
	avg_salary_rank = 1;
    
-- AS a data-driven Business consultant, you've been hired by a multinational corporation to analyze salary trends across different company 
-- Locations. Your goal is to Pinpoint Locations WHERE the average salary Has consistently Increased over the Past few years (Countries WHERE data 
-- is available for 3 years Only(present year and past two years) providing Insights into Locations experiencing Sustained salary growth

-- calculating avg salary for those countries WHERE data is available for 3 years Only(present year and past two years)
WITH cte1 AS (
SELECT 
	company_location, 
	work_year, 
    ROUND(AVG(salary_in_usd)) AS avg_salary_in_usd,
	COUNT(work_year) OVER(PARTITION BY company_location) AS distinct_years -- it will give count of distinct years
FROM 
	salaries
WHERE 
	work_year IN (2022, 2023, 2024)
GROUP BY 
	company_location, 
    work_year
),

-- adding new column prev_year to get previous_year_avg_salary and filtering the country where unique years count is 3
cte2 AS (
SELECT 
	company_location, 
	work_year, 
	avg_salary_in_usd,
	ROUND(LAG(avg_salary_in_usd, 1, 0) OVER(PARTITION BY company_location ORDER BY work_year)) AS prev_year_avg_salary_in_usd
FROM 
	cte1
WHERE 
	distinct_years = 3
),

-- calculating year on year growth rate
cte3 AS (
SELECT 
	company_location, 
	work_year, 
	COALESCE(100 * (avg_salary_in_usd - prev_year_avg_salary_in_usd) / prev_year_avg_salary, 0) AS yoy_growth
FROM 
	cte2
)

-- selecting all the countries with sustained average salary growth
SELECT 
	country, 
	work_year, 
    yoy_growth 
FROM 
	(SELECT 
		company_location AS country, 
        work_year, 
        yoy_growth,
		MIN(yoy_growth) OVER(PARTITION BY company_location) AS min_yoy_growth
	FROM cte3) tmp
WHERE 
	min_yoy_growth >= 0;
    
-- Picture yourself AS a workforce strategist employed by a global HR tech startup. Your Mission is to Determine the percentage of fully remote 
-- work for each experience level in 2021 and compare it WITH the corresponding figures for 2024, Highlighting any significant increases or decreases 
-- in remote work Adoption over the years.

-- calculating remote work percentage in each year for each experience level
WITH cte AS (
SELECT 
    work_year, 
    experience_level, 
    100 * SUM(CASE WHEN remote_ratio = 100 THEN 1 ELSE 0 END) / COUNT(*) AS remote_work_percentage
FROM 
	salaries
WHERE 
	work_year IN (2021, 2024)
GROUP BY 
	work_year, 
    experience_level
),

cte2 AS (
SELECT *,
    LAG(remote_work_percentage, 1) OVER(PARTITION BY experience_level ORDER BY work_year) AS prev_year_remote_work_percentage
FROM 
cte
)

-- calculating increase or decrease in remote work adoption over the years
SELECT 
    work_year,
    experience_level,
    IFNULL(100 * (remote_work_percentage - prev_year_remote_work_percentage) / prev_year_remote_work_percentage, 0) AS inc_dec
FROM 
	cte2;
    
-- AS a Compensation specialist at a Fortune 500 company, you're tasked with analyzing salary trends over time. Your objective is to calculate the 
-- average salary increase percentage for each experience level and job title between the years 2023 and 2024, helping the company stay competitive 
-- in the talent market.

-- calculating average salary for each job title based on experience level for year 2023 and 2024
WITH cte AS(
SELECT
    work_year,
    job_title,
    experience_level,
    AVG(salary_in_usd) AS avg_salary_in_usd,
    COUNT(*) OVER(PARTITION BY job_title, experience_level) AS unique_year
FROM 
	salaries
WHERE 
	work_year IN (2023, 2024)
GROUP BY 
	job_title, 
    experience_level, 
    work_year
),

-- filtering out the records where data for both years are not present 
cte2 AS (
SELECT *,
    LAG(avg_salary, 1) OVER(PARTITION BY job_title, experience_level ORDER BY work_year) AS prev_year_avg_salary_in_usd
FROM 
	cte
WHERE 
	unique_year = 2)

-- calculate salary trend based on job title and different experience level
SELECT 
	work_year, 
	job_title, 
    experience_level, 
    avg_salary_in_usd,
	COALESCE(ROUND(100 * (avg_salary - prev_year_avg_salary) / prev_year_avg_salary, 0), 0) AS salary_trend_based_on_exp_level_in_each_job
FROM 
	cte2;

