static void douyindisc_captionCases(DouyinDiscDisplay *driver, AWEMusicCoverButton *control) {
    UILabel *variant=[[UILabel alloc] initWithFrame:CGRectMake(-4,30,52,14)];
    variant.text=@"玩同款"; variant.alpha=.6; [control addSubview:variant];
    [driver douyindisc_refresh:control];
    DD_CHECK(variant.alpha==0 && variant.layer.mask, "exact 玩同款 variant is suppressed within the matched disc");
    variant.attributedText=[[NSAttributedString alloc] initWithString:@"玩同款"];
    [driver douyindisc_refresh:control];
    DD_CHECK(variant.alpha==0, "attributed 玩同款 variant is also suppressed");
    variant.text=@"试试玩同款";
    [driver douyindisc_refresh:control];
    DD_CHECK(fabs(variant.alpha-.6)<.001 && !variant.layer.mask, "containing text is not broadened into an exact variant match");
    [variant removeFromSuperview];
}
