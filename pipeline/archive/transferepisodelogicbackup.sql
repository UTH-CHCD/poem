DROP TABLE IF EXISTS CHCDWORK.dbo.poem_all_dx_episodes;

WITH EpisodeData AS (
    SELECT
        *,
        COALESCE(admit_date, clm_from_date) AS start_date,
        COALESCE(discharge_date, clm_to_date) AS end_date,
        ROW_NUMBER() OVER (PARTITION BY client_nbr ORDER BY COALESCE(admit_date, clm_from_date), COALESCE(discharge_date, clm_to_date)) AS rn
    FROM
        chcdwork.dbo.poem_all_dx_simplify
),
LagData AS (
    SELECT
        *,
        LAG(start_date) OVER (PARTITION BY client_nbr ORDER BY rn) AS prev_start_date,
        LAG(end_date) OVER (PARTITION BY client_nbr ORDER BY rn) AS prev_end_date,
        MAX(end_date) OVER (PARTITION BY client_nbr ORDER BY rn ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS max_end_date_before_current
    FROM
        EpisodeData
),
RunningPatStat AS (
    SELECT
        *,
        MAX(CASE WHEN pat_stat IN ('02', '05', '65', '82', '85', '88', '93', '94') THEN pat_stat ELSE NULL END)
        OVER (PARTITION BY client_nbr ORDER BY rn ROWS UNBOUNDED PRECEDING) AS running_pat_stat
    FROM
        LagData
),
EpisodeFlagData AS (
    SELECT
        *,
        CASE
            WHEN running_pat_stat IS NOT NULL AND prev_end_date = DATEADD(DAY, -1, start_date) THEN 0  -- Combine if exactly 1 day apart and there's a relevant running_pat_stat
            WHEN prev_start_date IS NULL THEN 1  -- Start a new episode if it's the first record for this client
            WHEN start_date > ISNULL(max_end_date_before_current, '1900-01-01') THEN 1  -- Start a new episode if the current start_date is after the max_end_date_before_current
            ELSE 0  -- Continue the current episode
        END AS NewEpisodeFlag
    FROM
        RunningPatStat
),
FinalGrouped AS (
    SELECT
        *,
        SUM(NewEpisodeFlag) OVER (PARTITION BY client_nbr ORDER BY rn ROWS UNBOUNDED PRECEDING) AS EpisodeGroup
    FROM
        EpisodeFlagData
),
RankedEpisodes AS (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY client_nbr ORDER BY EpisodeGroup) AS episode_id
    FROM
        FinalGrouped
)
SELECT
    *
INTO CHCDWORK.dbo.poem_all_dx_episodes
FROM
    RankedEpisodes
ORDER BY
    client_nbr, episode_id, start_date;