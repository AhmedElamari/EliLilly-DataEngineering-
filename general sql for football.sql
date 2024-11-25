--goalscorer creation and import via csv file for dummy data
CREATE TABLE goalscorers(
date DATE,
home_team varchar(50),
away_team varchar(50),
team varchar(50),
scorer varchar(50),
minute int NULL,
own_goal BOOLEAN DEFAULT FALSE,
penalty BOOLEAN DEFAULT FALSE
);
--results creation and import via csv file for dummy data
CREATE TABLE results(
date DATE NOT NULL,
home_team varchar(50),
away_team varchar(50),
home_score int NOT NULL CHECK (home_score >=0),
away_score int CHECK (away_score IS NULL OR away_score >=0),
tournament varchar(50) NOT NULL CHECK(tournament<> ''),
city varchar(50) CHECK (city IS NULL OR city <> ''),
country varchar(50) CHECK (country IS NULL OR country <> ''),
neutral boolean DEFAULT FALSE
CONSTRAINT chk_date_not_future CHECK (date<=CURRENT_DATE),
CONSTRAINT team_not_same CHECK(home_team<>away_team),
CONSTRAINT unique_match UNIQUE(date, home_team, away_team, home_score, away_score, tournament)
);
--shootouts creation and import via csv file for dummy data
CREATE TABLE shootouts(
date DATE NOT NULL,
home_team varchar(50),
away_team varchar(50),
winner varchar(50) CHECK(home_team<>away_team),
firstshooter varchar(50)
);
-- Query to calculate average number of goals per game between 1900 and 2000:
SELECT AVG(home_score + away_score) FROM results WHERE date BETWEEN '1900-01-01' and '2000-12-31';
-- create a query that counts the number of shootouts wins by country and arrange in alphabetical order:
SELECT WINNER, COUNT(WINNER) FROM shootouts GROUP BY winner ORDER BY WINNER;
--create a reliable key that allows the joining together of goalscorers, results and shootouts:
ALTER TABLE results ADD match_id serial;
ALTER TABLE results ADD primary key(match_id);
ALTER TABLE shootouts ADD match_id int REFERENCES results(match_id) ON DELETE cascade;
ALTER TABLE goalscorers ADD match_id int REFERENCES results(match_id) ON DELETE cascade;
SELECT r.date, r.home_team, r.away_team, r.home_score, r.away_score, g.scorer, g.team, s.winner
FROM results r
JOIN goalscorers g ON r.match_id = g.match_id
JOIN shootouts s ON r.match_id = s.match_id
ORDER BY r.date, r.home_team, r.away_team;
UPDATE shootouts SET match_id = r.match_id FROM results r WHERE shootouts.date = r.date
AND shootouts.home_team = r.home_team AND shootouts.away_team = r.away_team; 
UPDATE goalscorers SET match_id = r.match_id FROM results r WHERE goalscorers.date = r.date
AND goalscorers.home_team = r.home_team AND goalscorers.away_team = r.away_team;

SELECT r.match_id, r.date, r.home_team, r.away_team, r.home_score, r.away_score, g.scorer, g.team, s.winner
FROM results r
inner JOIN shootouts s ON r.match_id = s.match_id
inner JOIN goalscorers g ON r.match_id = g.match_id;
--Query that identifies which teams have won a penalty shootout after a 1-1 draw:
SELECT r.date, r.home_team, r.away_team, r.home_score, r.away_score, g.penalty ,s.winner
FROM results r
INNER JOIN shootouts s ON r.match_id = s.match_id
INNER JOIN goalscorers g ON r.match_id = g.match_id 
WHERE r.home_score=1 AND r.away_score = 1 AND g.penalty = TRUE;
--A query that identifes top goal scorer by tournament, and waht percentage that equates to for all goals scored in the tournament:
WITH total_goals_per_tournament AS (
SELECT tournament, COUNT(*) AS total_goals
FROM results
JOIN goalscorers ON results.match_id = goalscorers.match_id
GROUP BY tournament
),
top_scorer_per_tournament AS (
SELECT scorer, tournament, 
COUNT(*) AS goals_scored
FROM results
JOIN goalscorers ON results.match_id = goalscorers.match_id
GROUP BY  scorer, tournament
)
SELECT ts.scorer,ts.tournament,ts.goals_scored,tg.total_goals, 
ROUND((ts.goals_scored * 100.0) / tg.total_goals, 2) AS percentage
FROM top_scorer_per_tournament ts
JOIN total_goals_per_tournament tg ON ts.tournament = tg.tournament
WHERE  ts.goals_scored = (
SELECT MAX(goals_scored)
FROM top_scorer_per_tournament
WHERE tournament = ts.tournament)
ORDER BY tournament;
--ADDITIONAL column that flags records with data quality issues
WITH duplicate AS (
SELECT date, home_team, away_team, home_score, away_score, COUNT(*) AS occurance_count
FROM results
GROUP BY date, home_team, away_team, home_score, away_score
HAVING COUNT(*)>1
)
SELECT r.*,
CASE 
WHEN r.home_score <0 OR r.away_score < 0 THEN 'negative score'
WHEN d.occurance_count IS NOT NULL THEN 'duplicate occurance'
ELSE NULL
END AS DATA_QUALITY_FLAG
FROM RESULTS R
LEFT JOIN duplicate d ON r.date = d.date 
AND r.home_team = d.home_team
AND r.away_team = d.away_team
AND r.home_score = d.home_score
AND r.away_score = d.away_score;
--additional column for goalscorers as missing values for minute
SELECT *, 
CASE WHEN minute IS NULL THEN 'data missing' ELSE 'No Issues' 
END AS data_quality_flag
FROM goalscorers;



