#include "DouyinDiscPolicy.h"
#include <math.h>
#include <limits.h>

static bool douyindisc_valid(DouyinDiscRect r) {
    return isfinite(r.x) && isfinite(r.y) && isfinite(r.w) && isfinite(r.h) &&
           r.w > 0 && r.h > 0;
}

static double douyindisc_midx(DouyinDiscRect r) { return r.x + r.w * 0.5; }
static double douyindisc_midy(DouyinDiscRect r) { return r.y + r.h * 0.5; }

// Parse canonical ASCII decimal without accepting whitespace, signs or overflow.
static bool douyindisc_component(const char **cursor, unsigned *result) {
    const char *p = *cursor;
    if (*p < '0' || *p > '9' || (*p == '0' && p[1] >= '0' && p[1] <= '9')) return false;
    unsigned n = 0;
    do {
        unsigned digit = (unsigned)(*p++ - '0');
        if (n > (UINT_MAX - digit) / 10) return false;
        n = n * 10 + digit;
    } while (*p >= '0' && *p <= '9');
    *result = n;
    *cursor = p;
    return true;
}

bool douyindisc_version_supported(const char *version) {
    unsigned major, minor, patch;
    if (!version || !douyindisc_component(&version, &major) || *version++ != '.') return false;
    // In compact M.mp the two digits are separate minor and patch components.
    if (version[0] >= '0' && version[0] <= '9' && version[1] >= '0' && version[1] <= '9' && !version[2]) {
        minor = (unsigned)(version[0] - '0');
        patch = (unsigned)(version[1] - '0');
    } else if (!douyindisc_component(&version, &minor) || *version++ != '.' ||
               !douyindisc_component(&version, &patch) || *version) return false;
    return (major == 39 && minor >= 9) || major == 40 ||
           (major == 41 && (minor < 2 || (minor == 2 && patch == 0)));
}

bool douyindisc_disc_inside_rail(DouyinDiscRect disc, DouyinDiscRect window) {
    if (!douyindisc_valid(disc) || !douyindisc_valid(window) || window.w < 260 || window.h < 400) return false;
    if (disc.w < 22 || disc.w > 79 || disc.h < 22 || disc.h > 79 ||
        fabs(disc.w - disc.h) > fmax(disc.w, disc.h) * 0.26) return false;
    double x = douyindisc_midx(disc) - window.x;
    double y = douyindisc_midy(disc) - window.y;
    return x >= window.w * 0.79 && disc.x + disc.w <= window.x + window.w + 2 &&
           y >= window.h * 0.48 && y <= window.h * 0.98 && disc.y + disc.h <= window.y + window.h + 2;
}

bool douyindisc_share_above(DouyinDiscRect disc, DouyinDiscRect share, DouyinDiscRect window) {
    if (!douyindisc_disc_inside_rail(disc, window) || !douyindisc_valid(share) ||
        share.w < 18 || share.h < 18 || share.w > 110 || share.h > 110 ||
        share.x + share.w > window.x + window.w + 2 || share.y < window.y) return false;
    double dy = douyindisc_midy(disc) - douyindisc_midy(share);
    return dy >= 27 && dy <= 126 && fabs(douyindisc_midx(disc) - douyindisc_midx(share)) <= 19;
}

bool douyindisc_cover_fits(DouyinDiscRect cover, DouyinDiscRect disc) {
    if (!douyindisc_valid(cover) || !douyindisc_valid(disc)) return false;
    return cover.w >= disc.w * 0.57 && cover.w <= disc.w * 1.18 &&
           cover.h >= disc.h * 0.57 && cover.h <= disc.h * 1.18 &&
           fabs(douyindisc_midx(cover) - douyindisc_midx(disc)) <= disc.w * 0.18 &&
           fabs(douyindisc_midy(cover) - douyindisc_midy(disc)) <= disc.h * 0.18;
}
