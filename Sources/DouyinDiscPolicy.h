#ifndef DOUYINDISC_POLICY_H
#define DOUYINDISC_POLICY_H

#include <stdbool.h>

typedef struct {
    double x, y, w, h;
} DouyinDiscRect;

bool douyindisc_version_supported(const char *version);
bool douyindisc_disc_inside_rail(DouyinDiscRect disc, DouyinDiscRect window);
bool douyindisc_share_above(DouyinDiscRect disc, DouyinDiscRect share, DouyinDiscRect window);
bool douyindisc_cover_fits(DouyinDiscRect cover, DouyinDiscRect disc);

#endif
