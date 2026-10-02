import {
  type ConfigResponse,
  configResponse,
  type ErrorResponse,
} from "@emotely/contract";

const HTTP_OK = 200;
const HTTP_METHOD_NOT_ALLOWED = 405;

/**
 * Cached at the edge, so the app's startup call almost never reaches a
 * function: the answer is the same for every caller and changes only on a
 * deploy. `stale-while-revalidate` keeps the gate answering from cache while
 * a new value propagates — the app blocks when this request fails, so serving
 * a few seconds of staleness is strictly better than serving an error.
 */
export const CONFIG_CACHE_CONTROL =
  "public, max-age=0, s-maxage=300, stale-while-revalidate=600";

/**
 * The response differs by `?platform=`, so a shared cache must key on it —
 * otherwise the first caller's store link is served to every platform.
 * Vercel varies on the full URL including the query, so this is belt and
 * braces for any cache in front of it.
 */
const VARY = "platform";

/** The platforms that have a store of their own. Anything else is neutral. */
const STORE_BY_PLATFORM = {
  android: "storeUrlAndroid",
  ios: "storeUrlIos",
} as const;
type Platform = keyof typeof STORE_BY_PLATFORM;

function isPlatform(value: string | null): value is Platform {
  return value !== null && Object.hasOwn(STORE_BY_PLATFORM, value);
}

/**
 * `GET /api/config`: what the app must know before it may run.
 *
 * Deliberately unauthenticated, unlike the session endpoint (ADR 0010). The
 * users this endpoint exists to block are on a version the server no longer
 * serves; making them sign in first to learn that puts the sign-in screen —
 * which may itself have moved on — in front of the force-update screen. The
 * body holds nothing private: a version number and a public store link.
 *
 * No signing, no model call, no user lookup: the cost profile of a static
 * file, which is what lets a public path carry its own rate-limit rule
 * cheaply (ADR 0008).
 */
export function createConfigHandler(config: {
  /** Oldest app version this server still serves; the app blocks below it. */
  minAppVersion: string;
  /**
   * Where the force-update screen sends a caller whose platform we do not
   * recognize (or that did not say). The releases page until the store
   * listings exist (#9).
   */
  storeUrl: string;
  /** The App Store listing, for `?platform=ios`. */
  storeUrlIos: string;
  /** The Play listing, for `?platform=android`. */
  storeUrlAndroid: string;
}) {
  // Validate once per cold start, not per request: a malformed constant is a
  // deploy-time bug, and an app that cannot parse the minimum would block
  // every user. Failing here fails the deploy's first request loudly instead.
  // Every variant is validated, so a typo in the iOS link cannot hide behind
  // an Android request.
  const payloads = new Map<Platform | "neutral", string>(
    (
      [
        ["neutral", config.storeUrl],
        ["ios", config.storeUrlIos],
        ["android", config.storeUrlAndroid],
      ] as const
    ).map(([key, storeUrl]) => [
      key,
      JSON.stringify(
        configResponse.parse({
          min_app_version: config.minAppVersion,
          store_url: storeUrl,
        }) satisfies ConfigResponse,
      ),
    ]),
  );

  return (request: Request): Promise<Response> => {
    // Vercel's method-export routing already rejects anything but GET/HEAD
    // before this runs, so in production this branch is unreachable. Kept
    // because the handler is a plain function the CLI and the tests call
    // directly, and it must not answer a POST there either — the same
    // belt-and-braces check `createAdvanceSessionHandler` makes.
    if (request.method !== "GET" && request.method !== "HEAD") {
      return Promise.resolve(getOnly());
    }
    // The app names its own platform; anything unrecognized gets the neutral
    // link rather than an error. Someone blocked by the version gate cannot
    // install a build that would send a better parameter, so a request we
    // cannot classify must still answer with somewhere to go.
    const platform = new URL(request.url).searchParams.get("platform");
    const payload = payloads.get(isPlatform(platform) ? platform : "neutral");
    return Promise.resolve(
      new Response(payload, {
        status: HTTP_OK,
        headers: {
          "content-type": "application/json",
          "cache-control": CONFIG_CACHE_CONTROL,
          vary: VARY,
        },
      }),
    );
  };
}

/** The 405 for anything but GET/HEAD, in the agent's error envelope. */
function getOnly(): Response {
  return new Response(
    JSON.stringify({
      code: "method_not_allowed",
      error: "GET only",
    } satisfies ErrorResponse),
    {
      status: HTTP_METHOD_NOT_ALLOWED,
      headers: { "content-type": "application/json" },
    },
  );
}
