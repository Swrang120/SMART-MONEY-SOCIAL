# Smart Money Social

Standalone social-network frontend. **All Social development and deployment belongs in this repository.** The separate main Smart Money application is out of scope and must not be modified.

## Social experience

The current frontend includes:
- For You, Following, Trending and Latest feed views
- Text/photo posts, hashtags, likes, comments, saves, shares and reports
- Stories (video is allowed only in Stories)
- User profiles, profile editing, follows and suggested people
- Explore/search and notifications
- Community photo/text posts with moderation flow
- Member discovery and private text messaging
- Block controls and realtime refresh subscriptions
- Responsive mobile layout and PWA manifest metadata

## GitHub Pages deployment

A GitHub Actions workflow deploys the repository root on every push to `main`.

1. Open this repository's **Settings → Pages**.
2. Set **Build and deployment → Source** to **GitHub Actions**.
3. Push to `main` or run **Deploy Smart Money Social to GitHub Pages** from the Actions tab.
4. Site URL: https://swrang120.github.io/SMART-MONEY-SOCIAL/

## Backend dependency

The current HTML frontend connects to the existing Smart Money Social Supabase project and uses its separate auth storage key `smart-money-social-auth-v1`. It expects these Social-only tables:

`social_access`, `social_profiles`, `social_posts`, `social_stories`, `social_likes`, `social_comments`, `social_follows`, `social_saved_posts`, `social_reports`, `social_notifications`, `social_messages`, `social_message_blocks`.

It also expects the private Storage bucket `smart-money-social`.

**Do not disable RLS or make the bucket public.** Any missing table, policy or storage rule must be handled as a Social-scoped migration only, with a backup and explicit approval. Do not alter main Smart Money auth, tables, payment gateway, packages, withdrawals or Academy.

### Guest mode

The current UI attempts Supabase anonymous sign-in. If anonymous sign-in is disabled in Supabase Auth Providers, guest startup will fail until that provider is enabled. That provider setting has not been changed by this repository setup. Guest profiles may not be recoverable after browser storage is cleared; a permanent account-linking flow is needed before treating guest accounts as permanent identities.

## Media constraints

- Feed and Community posts: text and photos only.
- Stories: image or video.
- Community post photo limit: 8 MB in the current UI.
- Private messages: text only.

## Security

Browser publishable/anon keys are designed for client use, but all data access must be enforced with strict RLS and Storage policies. Never add service-role keys, admin secrets or private API credentials to frontend code. Admin/moderation permissions must be enforced server-side/database-side, not merely by hiding UI controls.
