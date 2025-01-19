-- Remove specified users and their data
DO $$
DECLARE
    v_user_emails text[] := ARRAY['clay@healthrocket.life', 'chuck@healthrocket.life', 'joseph@healthrocket.life'];
    v_user_id uuid;
    v_email text;
BEGIN
    -- Log start of cleanup
    RAISE NOTICE 'Starting user cleanup...';

    -- Process each user
    FOREACH v_email IN ARRAY v_user_emails
    LOOP
        -- Get user ID from auth.users
        SELECT id INTO v_user_id
        FROM auth.users
        WHERE email = v_email;

        IF FOUND THEN
            RAISE NOTICE 'Processing user %: %', v_email, v_user_id;

            -- Delete from all related tables (foreign keys will cascade)
            DELETE FROM public.users
            WHERE id = v_user_id;

            -- Delete from auth.users
            DELETE FROM auth.users
            WHERE id = v_user_id;

            RAISE NOTICE 'Successfully removed user: %', v_email;
        ELSE
            RAISE NOTICE 'User not found: %', v_email;
        END IF;
    END LOOP;

    RAISE NOTICE 'User cleanup complete';
END $$;