#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Returns one of: ar, en, es, fa, fr, pt.
 * The value is read from Telegram/Whitegram's own cached base-language key
 * (wg_tgBaseLanguageCode), then falls back to the app and system languages.
 */
FOUNDATION_EXPORT NSString *WGCurrentTelegramLanguageCode(void);
FOUNDATION_EXPORT BOOL WGCurrentLanguageIsRTL(void);
FOUNDATION_EXPORT UISemanticContentAttribute WGCurrentSemanticContentAttribute(void);
FOUNDATION_EXPORT NSTextAlignment WGCurrentTextAlignment(void);

FOUNDATION_EXPORT BOOL WGLocalizationEnabled(void);
FOUNDATION_EXPORT NSString *WGTranslateString(NSString *input);
FOUNDATION_EXPORT NSAttributedString *WGTranslateAttributedString(NSAttributedString *input);

NS_ASSUME_NONNULL_END
