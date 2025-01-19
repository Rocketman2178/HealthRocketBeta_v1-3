-- Add name column to users table
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS display_name text;

-- Update display_name from existing name column
UPDATE public.users
SET display_name = name
WHERE display_name IS NULL;

-- Add name column to daily_fp table
ALTER TABLE public.daily_fp
ADD COLUMN IF NOT EXISTS user_name text;

-- Update daily_fp user_name from users table
UPDATE public.daily_fp df
SET user_name = u.name
FROM public.users u
WHERE df.user_id = u.id
AND df.user_name IS NULL;

-- Create trigger to keep daily_fp user_name in sync
CREATE OR REPLACE FUNCTION sync_daily_fp_user_name()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Update user_name in daily_fp when user's name changes
    UPDATE daily_fp
    SET user_name = NEW.name
    WHERE user_id = NEW.id;
    
    RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS sync_daily_fp_user_name_trigger ON users;
CREATE TRIGGER sync_daily_fp_user_name_trigger
    AFTER UPDATE OF name ON users
    FOR EACH ROW
    WHEN (OLD.name IS DISTINCT FROM NEW.name)
    EXECUTE FUNCTION sync_daily_fp_user_name();