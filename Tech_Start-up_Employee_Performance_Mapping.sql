# Create Database
CREATE DATABASE Tech;
USE Tech;

# Table data import wizard, Import emp, dept, rating-aisa, rating-eu, rating-north america, rating-south america tables

# Combine the 4 rating tables into one view for easier querying
CREATE VIEW unified_ratings AS
SELECT * FROM `rating-asia`
UNION ALL
SELECT * FROM `rating-eu`
UNION ALL
SELECT * FROM `rating-na`
UNION ALL
SELECT * FROM `rating-sa`;

# Average salary by role, continent, and country, (how to do multiple costome order?)
SELECT 
    d.ROLE,
    u.CONTINENT,
    u.COUNTRY,
    AVG(e.SALARY) AS avg_salary
FROM emp e
JOIN dept d ON e.EMP_ID = d.EMP_ID
JOIN unified_ratings u ON e.EMP_ID = u.EMP_ID
GROUP BY d.ROLE, u.CONTINENT, u.COUNTRY
ORDER BY 
    CASE d.ROLE
        WHEN 'President' THEN 1
        WHEN 'Lead' THEN 2
        WHEN 'Senior' THEN 3
        WHEN 'Associate' THEN 4
        WHEN 'Junior' THEN 5
        ELSE 6
    END,
    avg_salary DESC;
    
#Count of employees by rating distribution
SELECT
    SUM(CASE WHEN EMP_RATING < 2 THEN 1 ELSE 0 END) AS rating_below_2,
    SUM(CASE WHEN EMP_RATING > 4 THEN 1 ELSE 0 END) AS rating_above_4,
    SUM(CASE WHEN EMP_RATING BETWEEN 2 AND 4 THEN 1 ELSE 0 END) AS rating_between_2_and_4
FROM unified_ratings;

SELECT
    continent,
    SUM(CASE WHEN EMP_RATING < 2 THEN 1 ELSE 0 END) AS rating_below_2,
    SUM(CASE WHEN EMP_RATING > 4 THEN 1 ELSE 0 END) AS rating_above_4,
    SUM(CASE WHEN EMP_RATING BETWEEN 2 AND 4 THEN 1 ELSE 0 END) AS rating_between_2_and_4
FROM unified_ratings
GROUP BY continent;

#Average performance rating by department
SELECT 
    d.DEPT,
    AVG(u.EMP_RATING) AS avg_rating
FROM dept d
JOIN unified_ratings u ON d.EMP_ID = u.EMP_ID
GROUP BY d.DEPT;

#Bonus calculation (5% of salary * rating)
SELECT 
    e.EMP_ID,
    e.FIRST_NAME,
    e.LAST_NAME,
	u.CONTINENT,
    u.COUNTRY,
    d.DEPT,
    e.SALARY,
    u.EMP_RATING,
    (0.05 * e.SALARY * u.EMP_RATING) AS BONUS
FROM emp e
JOIN unified_ratings u ON e.EMP_ID = u.EMP_ID
JOIN dept d ON e.EMP_ID = d.EMP_ID
ORDER BY
    u.CONTINENT,
    u.COUNTRY,
    d.DEPT,
    e.SALARY DESC;

# Stored function to match experience to standard role
DELIMITER //
CREATE FUNCTION Check_Role_Standard(exp INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE role_standard VARCHAR(20);
    IF exp <= 2 THEN
        SET role_standard = 'JUNIOR';
    ELSEIF exp > 2 AND exp <= 5 THEN
        SET role_standard = 'ASSOCIATE';
    ELSEIF exp > 5 AND exp <= 10 THEN
        SET role_standard = 'SENIOR';
    ELSEIF exp > 10 AND exp <= 12 THEN
        SET role_standard = 'LEAD';
    ELSEIF exp > 12 AND exp <= 16 THEN
        SET role_standard = 'MANAGER';
    ELSE
        SET role_standard = 'UNKNOWN';
    END IF;
    RETURN role_standard;
END //
DELIMITER ;

SELECT 
    e.EMP_ID,
    e.EXP,
    d.ROLE,
    Check_Role_Standard(e.EXP) AS Expected_Role
FROM emp e
JOIN dept d ON e.EMP_ID = d.EMP_ID;

# Compare employee experience to average for their role
SELECT 
    e.EMP_ID,
    e.FIRST_NAME,
    d.ROLE,
    e.EXP,
    (SELECT AVG(e2.EXP)
     FROM emp e2
     JOIN dept d2 ON e2.EMP_ID = d2.EMP_ID
     WHERE d2.ROLE = d.ROLE) AS avg_exp_for_role
FROM emp e
JOIN dept d ON e.EMP_ID = d.EMP_ID;

# Rating percentile rank within department
SELECT 
    d.DEPT,
    e.EMP_ID,
    e.FIRST_NAME,
    u.EMP_RATING,
    PERCENT_RANK() OVER (PARTITION BY d.DEPT ORDER BY u.EMP_RATING) AS rating_percentile
FROM emp e
JOIN dept d ON e.EMP_ID = d.EMP_ID
JOIN unified_ratings u ON e.EMP_ID = u.EMP_ID;

# Recommend training or promotion
WITH Standard_Exp AS (
    SELECT 'JUNIOR' AS ROLE, 2 AS EXP UNION
    SELECT 'ASSOCIATE', 5 UNION
    SELECT 'SENIOR', 10 UNION
    SELECT 'LEAD', 12 UNION
    SELECT 'MANAGER', 16
),
Rating_Perc AS (
    SELECT 
        d.EMP_ID,
        d.ROLE,
        d.DEPT,
        u.EMP_RATING,
        PERCENT_RANK() OVER (PARTITION BY d.DEPT ORDER BY u.EMP_RATING) AS rating_percentile
    FROM dept d
    JOIN unified_ratings u ON d.EMP_ID = u.EMP_ID
)
SELECT 
    e.EMP_ID,
    e.EXP,
    d.ROLE,
    rp.EMP_RATING,
    rp.rating_percentile,
    CASE 
        WHEN e.EXP < se.EXP AND rp.rating_percentile <= 0.5 THEN 'Need Training'
        WHEN e.EXP > se.EXP AND rp.rating_percentile >= 0.5 THEN 'Promotion'
        WHEN e.EXP > (
            SELECT AVG(e2.EXP)
            FROM emp e2 JOIN dept d2 ON e2.EMP_ID = d2.EMP_ID
            WHERE d2.ROLE = d.ROLE
        ) AND rp.rating_percentile >= 0.67 THEN 'Promotion'
        ELSE 'No Action'
    END AS Recommendation
FROM emp e
JOIN dept d ON e.EMP_ID = d.EMP_ID
JOIN Standard_Exp se ON d.ROLE = se.ROLE
JOIN Rating_Perc rp ON e.EMP_ID = rp.EMP_ID;

# Stored procedure to retrieve employees by continent
DELIMITER //
CREATE PROCEDURE Get_Employees_By_Region(IN region_name VARCHAR(50))
BEGIN
    SELECT 
        e.EMP_ID,
        e.FIRST_NAME,
        e.LAST_NAME,
        u.CONTINENT,
        u.COUNTRY,
        d.DEPT,
        u.EMP_RATING
    FROM emp e
    JOIN unified_ratings u ON e.EMP_ID = u.EMP_ID
    JOIN dept d ON e.EMP_ID = d.EMP_ID
    WHERE u.CONTINENT = region_name;
END //
DELIMITER ;

CALL Get_Employees_By_Region('Asia');

# Create index for searching by name
SELECT * FROM emp WHERE FIRST_NAME = 'Eric';

EXPLAIN SELECT * FROM emp WHERE FIRST_NAME = 'Eric';

CREATE INDEX idx_name ON emp(FIRST_NAME(50), LAST_NAME(50));

SELECT * FROM emp WHERE FIRST_NAME = 'Eric';

EXPLAIN SELECT * FROM emp WHERE FIRST_NAME = 'Eric';