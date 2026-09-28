# Inviting a beta tester

An invitation is one link, `https://getemotely.com/beta` (unlisted, see
`apps/web/lib/pages/beta.dart`). iPhone testers need nothing from us;
Android testers need their Google account on a list first. Adding
someone's address to a console is entering personal data, so an agent does
it only when the person asking has said yes to that address.

Before the first invite of a wave, check that the build you want them on
is in `Beta` and approved on the closed track (the waits in `SKILL.md`):
Play shows **Release status** per track under **Test and release → Latest
releases and bundles**.

## iPhone

1. Send the invitation with the beta page link. The page's **Join on
   TestFlight** button is the public link of the external group `Beta`
   (capped at 100 testers).

Done when the tester shows up under **App Store Connect → TestFlight →
Beta → Testers**. To remove someone, delete them there.

## Android

1. Ask for the **Google account address that is signed in to the Play
   Store on their phone**. Any other address fails: the opt-in link admits
   only listed accounts.
2. Open the closed track's Testers tab:

   <https://play.google.com/console/u/0/developers/5174249003608815741/app/4975881213380590767/tracks/4699634478614053584?tab=testers>

   (**Test and release → Testing → Closed testing → Closed testing -
   Alpha → Testers**.) If the link lands on **All apps**, open the app's
   dashboard once in that tab and follow the link again.
3. In the **Email lists** table, click the arrow on the **emotely beta**
   row. It is the ticked list; `Tester` is the legacy list and stays
   unticked.
4. In the **Edit email list** dialog, type the address into **Add email
   addresses**, press **Enter**, and click **Save changes**. The track
   already uses this list, so nothing else on the page needs saving.
5. Send the invitation with the beta page link. They tap **Join on Google
   Play** with that same account, then install from the Play Store.

Done when the address is listed under **Email addresses added** in the
dialog. To remove someone, click the bin next to their address and save.

**Germany only.** The closed track targets one country (**Countries/regions**
tab, managed separately from production). A tester whose Play Store country
is elsewhere cannot install: add their country via **Edit
countries/regions** on that tab before inviting them.

## Keep track of the wave

App events carry no `utm_*`, so a wave is told apart by its start date and
build number. Write down who was invited, on which platform, when, and on
which build — outside the repo, since it names people. The PostHog `Beta`
dashboard then reads the wave by `$app_version`.
