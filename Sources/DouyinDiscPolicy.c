#include "DouyinDiscPolicy.h"
#include <math.h>
#include <string.h>

static bool douyindisc_valid(DouyinDiscRect r) {
    return isfinite(r.x) && isfinite(r.y) && isfinite(r.w) && isfinite(r.h) &&
           r.w > 0 && r.h > 0;
}

static double douyindisc_midx(DouyinDiscRect r) { return r.x + r.w * 0.5; }
static double douyindisc_midy(DouyinDiscRect r) { return r.y + r.h * 0.5; }

bool douyindisc_version_supported(const char *version) {
    return version && (!strcmp(version, "39.90") || !strcmp(version, "39.9.0"));
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
