-- Create function to check user's burn streak
CREATE OR REPLACE FUNCTION check_user_burn_streak(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_today date;
    v_yesterday date;
    v_today_boosts integer;
    v_yesterday_boosts integer;
    v_current_streak integer;
BEGIN
    -- Get dates in EDT
    v_today := (current_timestamp AT TIME ZONE 'America/New_York')::date;
    v_yesterday := v_today - 1;

    -- Get today's boost count
    SELECT COUNT(*)
    INTO v_today_boosts
    FROM completed_boosts
    WHERE user_id = p_user_id
    AND completed_date = v_today;

    -- Get yesterday's boost count
    SELECT COUNT(*)
    INTO v_yesterday_boosts
    FROM completed_boosts
    WHERE user_id = p_user_id
    AND completed_date = v_yesterday;

    -- Get current streak
    SELECT burn_streak
    INTO v_current_streak
    FROM users
    WHERE id = p_user_id;

    -- Calculate correct streak
    IF v_today_boosts > 0 THEN
        -- If we have boosts today, streak should be 1 or incremented
        IF v_yesterday_boosts > 0 THEN
            -- Had boosts yesterday, increment streak
            v_current_streak := COALESCE(v_current_streak, 0) + 1;
        ELSE
            -- No boosts yesterday, start new streak
            v_current_streak := 1;
        END IF;
    ELSE
        -- No boosts today, check if streak should be 0
        IF v_yesterday_boosts = 0 THEN
            -- No boosts yesterday either, reset streak
            v_current_streak := 0;
        END IF;
    END IF;

    -- Update user's burn streak
    UPDATE users
    SET burn_streak = v_current_streak
    WHERE id = p_user_id;

    RETURN jsonb_build_object(
        'today_boosts', v_today_boosts,
        'yesterday_boosts', v_yesterday_boosts,
        'new_streak', v_current_streak
    );
END;
$$;

-- Fix Test User 25's burn streak
DO $$
DECLARE
    v_user_id uuid;
    v_result jsonb;
BEGIN
    -- Get Test User 25's ID
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = 'test25@gmail.com';

    -- Check and fix burn streak
    SELECT check_user_burn_streak(v_user_id) INTO v_result;

    -- Log results
    RAISE NOTICE 'Burn streak check results for Test User 25: %', v_result;
END $$;