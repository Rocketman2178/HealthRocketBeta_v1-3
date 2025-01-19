-- Drop existing trigger and function
DROP TRIGGER IF EXISTS update_verification_count ON chat_messages;
DROP FUNCTION IF EXISTS update_challenge_verification();

-- Create improved trigger function to update challenge verification count
CREATE OR REPLACE FUNCTION update_challenge_verification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_challenge_id text;
    v_verification_count integer;
    v_required_verifications integer;
BEGIN
    -- Only proceed if this is a verification message
    IF NEW.is_verification = true THEN
        -- Extract challenge_id from chat_id (remove 'c_' prefix)
        v_challenge_id := substring(NEW.chat_id from 3);
        
        -- Get current verification count including the new message
        WITH verification_messages AS (
            SELECT COUNT(*) as count
            FROM chat_messages
            WHERE chat_id = NEW.chat_id
            AND user_id = NEW.user_id
            AND is_verification = true
            AND id IS NOT NULL  -- Ensure message exists
        )
        SELECT count INTO v_verification_count
        FROM verification_messages;

        -- Get required verifications for this challenge
        SELECT COALESCE(verifications_required, 3)
        INTO v_required_verifications
        FROM challenges 
        WHERE challenge_id = v_challenge_id
        AND user_id = NEW.user_id
        AND status = 'active';

        -- Update challenge verification count and progress
        UPDATE challenges
        SET 
            verification_count = v_verification_count,
            progress = LEAST((v_verification_count::numeric / v_required_verifications * 100), 100),
            updated_at = now()
        WHERE challenge_id = v_challenge_id
        AND user_id = NEW.user_id
        AND status = 'active';

        -- Log verification update
        RAISE NOTICE 'Updated verification count for challenge % to % (required: %)', 
            v_challenge_id, 
            v_verification_count,
            v_required_verifications;
    END IF;

    RETURN NEW;
END;
$$;

-- Create new trigger
CREATE TRIGGER update_verification_count
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_challenge_verification();

-- Recount and fix all verification counts
DO $$
DECLARE
    v_challenge record;
    v_verification_count integer;
    v_progress numeric;
BEGIN
    FOR v_challenge IN (
        SELECT c.*, u.email
        FROM challenges c
        JOIN users u ON u.id = c.user_id
        WHERE c.status = 'active'
    ) LOOP
        -- Get actual verification count
        WITH verification_messages AS (
            SELECT COUNT(*) as count
            FROM chat_messages
            WHERE chat_id = 'c_' || v_challenge.challenge_id
            AND user_id = v_challenge.user_id
            AND is_verification = true
            AND id IS NOT NULL  -- Ensure message exists
        )
        SELECT count INTO v_verification_count
        FROM verification_messages;

        -- Calculate progress
        v_progress := LEAST(
            (v_verification_count::numeric / COALESCE(v_challenge.verifications_required, 3) * 100),
            100
        );

        -- Update challenge
        UPDATE challenges
        SET 
            verification_count = v_verification_count,
            progress = v_progress
        WHERE challenge_id = v_challenge.challenge_id
        AND user_id = v_challenge.user_id;

        -- Log the update
        RAISE NOTICE 'Fixed challenge % for user %: Count=%, Progress=%', 
            v_challenge.challenge_id,
            v_challenge.email,
            v_verification_count,
            v_progress;
    END LOOP;
END $$;