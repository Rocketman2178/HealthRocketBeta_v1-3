-- Drop existing function
DROP FUNCTION IF EXISTS update_health_assessment;

-- Create new function with correct parameter order
CREATE OR REPLACE FUNCTION update_health_assessment(
  p_user_id uuid,
  p_expected_lifespan integer,
  p_expected_healthspan integer,
  p_health_score numeric,
  p_mindset_score numeric,
  p_sleep_score numeric,
  p_exercise_score numeric,
  p_nutrition_score numeric,
  p_biohacking_score numeric,
  p_created_at timestamptz
) RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_level integer;
  v_next_level_points integer;
  v_fp_bonus integer;
  v_today date;
  v_result jsonb;
  v_initial_healthspan integer;
  v_healthspan_years numeric;
BEGIN
  -- Verify user permissions
  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Input validation
  IF p_expected_lifespan < 50 OR p_expected_lifespan > 200 THEN
    RAISE EXCEPTION 'Expected lifespan must be between 50 and 200 years';
  END IF;

  IF p_expected_healthspan < 50 OR p_expected_healthspan > p_expected_lifespan THEN
    RAISE EXCEPTION 'Expected healthspan must be between 50 years and expected lifespan';
  END IF;

  -- Get user's current level
  SELECT level INTO v_level
  FROM users
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Get initial healthspan
  v_initial_healthspan := get_initial_healthspan(p_user_id);
  
  -- If this is the first assessment, set initial healthspan
  IF v_initial_healthspan IS NULL THEN
    v_initial_healthspan := p_expected_healthspan;
    
    UPDATE users 
    SET initial_healthspan = v_initial_healthspan
    WHERE id = p_user_id;
  END IF;

  -- Calculate healthspan years gained
  v_healthspan_years := p_expected_healthspan - v_initial_healthspan;

  -- Calculate next level points
  v_next_level_points := round(20 * power(1.41, v_level - 1));
  v_fp_bonus := round(v_next_level_points * 0.1);
  v_today := CURRENT_DATE;

  -- Update user profile
  UPDATE users SET
    lifespan = p_expected_lifespan,
    healthspan = p_expected_healthspan,
    healthspan_years = v_healthspan_years,
    health_score = p_health_score,
    fuel_points = fuel_points + v_fp_bonus,
    onboarding_completed = true
  WHERE id = p_user_id;

  -- Insert health assessment
  INSERT INTO health_assessments (
    user_id,
    expected_lifespan,
    expected_healthspan,
    health_score,
    healthspan_years,
    previous_healthspan,
    mindset_score,
    sleep_score,
    exercise_score,
    nutrition_score,
    biohacking_score,
    created_at
  ) VALUES (
    p_user_id,
    p_expected_lifespan,
    p_expected_healthspan,
    p_health_score,
    v_healthspan_years,
    v_initial_healthspan,
    p_mindset_score,
    p_sleep_score,
    p_exercise_score,
    p_nutrition_score,
    p_biohacking_score,
    p_created_at
  );

  -- Update daily FP
  INSERT INTO daily_fp (
    user_id,
    date,
    fp_earned,
    health_assessment_bonus
  ) VALUES (
    p_user_id,
    v_today,
    COALESCE((SELECT fp_earned FROM daily_fp WHERE user_id = p_user_id AND date = v_today), 0) + v_fp_bonus,
    v_fp_bonus
  )
  ON CONFLICT (user_id, date) 
  DO UPDATE SET
    fp_earned = daily_fp.fp_earned + v_fp_bonus,
    health_assessment_bonus = v_fp_bonus;

  -- Prepare success response
  v_result := jsonb_build_object(
    'success', true,
    'fp_bonus', v_fp_bonus,
    'health_score', p_health_score,
    'healthspan_years', v_healthspan_years,
    'assessment_date', p_created_at
  );

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    -- Return error response
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;