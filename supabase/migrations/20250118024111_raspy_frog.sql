-- Add user_name column to completed_boosts
ALTER TABLE public.completed_boosts
ADD COLUMN IF NOT EXISTS user_name text;

-- Add user_name column to challenges
ALTER TABLE public.challenges
ADD COLUMN IF NOT EXISTS user_name text;

-- Add user_name column to quests
ALTER TABLE public.quests
ADD COLUMN IF NOT EXISTS user_name text;

-- Add user_name column to health_assessments
ALTER TABLE public.health_assessments
ADD COLUMN IF NOT EXISTS user_name text;

-- Add user_name column to support_messages
ALTER TABLE public.support_messages
ADD COLUMN IF NOT EXISTS user_name text;

-- Add user_name column to chat_messages
ALTER TABLE public.chat_messages
ADD COLUMN IF NOT EXISTS user_name text;

-- Add user_name column to community_memberships
ALTER TABLE public.community_memberships
ADD COLUMN IF NOT EXISTS user_name text;

-- Update all user_name columns from users table
UPDATE public.completed_boosts cb
SET user_name = u.name
FROM public.users u
WHERE cb.user_id = u.id
AND cb.user_name IS NULL;

UPDATE public.challenges c
SET user_name = u.name
FROM public.users u
WHERE c.user_id = u.id
AND c.user_name IS NULL;

UPDATE public.quests q
SET user_name = u.name
FROM public.users u
WHERE q.user_id = u.id
AND q.user_name IS NULL;

UPDATE public.health_assessments ha
SET user_name = u.name
FROM public.users u
WHERE ha.user_id = u.id
AND ha.user_name IS NULL;

UPDATE public.support_messages sm
SET user_name = u.name
FROM public.users u
WHERE sm.user_id = u.id
AND sm.user_name IS NULL;

UPDATE public.chat_messages cm
SET user_name = u.name
FROM public.users u
WHERE cm.user_id = u.id
AND cm.user_name IS NULL;

UPDATE public.community_memberships cm
SET user_name = u.name
FROM public.users u
WHERE cm.user_id = u.id
AND cm.user_name IS NULL;

-- Create function to sync user names across all tables
CREATE OR REPLACE FUNCTION sync_user_names()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only proceed if name has changed
    IF OLD.name IS DISTINCT FROM NEW.name THEN
        -- Update completed_boosts
        UPDATE completed_boosts
        SET user_name = NEW.name
        WHERE user_id = NEW.id;

        -- Update challenges
        UPDATE challenges
        SET user_name = NEW.name
        WHERE user_id = NEW.id;

        -- Update quests
        UPDATE quests
        SET user_name = NEW.name
        WHERE user_id = NEW.id;

        -- Update health_assessments
        UPDATE health_assessments
        SET user_name = NEW.name
        WHERE user_id = NEW.id;

        -- Update support_messages
        UPDATE support_messages
        SET user_name = NEW.name
        WHERE user_id = NEW.id;

        -- Update chat_messages
        UPDATE chat_messages
        SET user_name = NEW.name
        WHERE user_id = NEW.id;

        -- Update community_memberships
        UPDATE community_memberships
        SET user_name = NEW.name
        WHERE user_id = NEW.id;
    END IF;

    RETURN NEW;
END;
$$;

-- Create trigger to keep user names in sync
DROP TRIGGER IF EXISTS sync_user_names_trigger ON users;
CREATE TRIGGER sync_user_names_trigger
    AFTER UPDATE OF name ON users
    FOR EACH ROW
    EXECUTE FUNCTION sync_user_names();