#import "WGTranslations.h"
#include "GeneratedTranslations.inc"

static NSString * const WGLocalizationEnabledDefaultsKey = @"WGLocalizationEnabled";
static NSString * const WGTelegramBaseLanguageDefaultsKey = @"wg_tgBaseLanguageCode";

static NSSet<NSString *> *WGSupportedLanguageCodes(void) {
    static NSSet<NSString *> *codes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        codes = [NSSet setWithArray:@[@"ar", @"en", @"es", @"fa", @"fr", @"pt"]];
    });
    return codes;
}

static NSString *WGNormalizeLanguageCode(NSString *rawCode) {
    if (![rawCode isKindOfClass:NSString.class] || rawCode.length == 0) {
        return nil;
    }

    NSString *normalized = [[rawCode stringByReplacingOccurrencesOfString:@"_" withString:@"-"] lowercaseString];
    normalized = [normalized stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (normalized.length == 0 ||
        [normalized isEqualToString:@"system"] ||
        [normalized isEqualToString:@"default"] ||
        [normalized isEqualToString:@"auto"] ||
        [normalized isEqualToString:@"base"]) {
        return nil;
    }

    NSString *primary = [[normalized componentsSeparatedByString:@"-"] firstObject];
    if ([primary isEqualToString:@"iw"]) {
        primary = @"he";
    }
    return [WGSupportedLanguageCodes() containsObject:primary] ? primary : nil;
}

static NSString *WGCodeFromObject(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return WGNormalizeLanguageCode((NSString *)value);
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id item in (NSArray *)value) {
            NSString *code = WGCodeFromObject(item);
            if (code) {
                return code;
            }
        }
    }
    return nil;
}

static NSString *WGTelegramCachedLanguageCode(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;

    /*
     * Whitegram 12.8 exports TelegramCore.SGSettings.wgTelegramBaseLanguageCode
     * and stores it under this exact preference key. This is the closest match
     * to Telegram's in-app language and can differ from the iPhone language.
     */
    NSString *code = WGCodeFromObject([defaults objectForKey:WGTelegramBaseLanguageDefaultsKey]);
    if (code) {
        return code;
    }

    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    if (bundleIdentifier.length > 0) {
        NSDictionary *domain = [defaults persistentDomainForName:bundleIdentifier];
        code = WGCodeFromObject(domain[WGTelegramBaseLanguageDefaultsKey]);
        if (code) {
            return code;
        }
    }

    return nil;
}

NSString *WGCurrentTelegramLanguageCode(void) {
    NSString *code = WGTelegramCachedLanguageCode();
    if (code) {
        return code;
    }

    code = WGCodeFromObject([NSUserDefaults.standardUserDefaults objectForKey:@"AppleLanguages"]);
    if (code) {
        return code;
    }

    code = WGCodeFromObject(NSBundle.mainBundle.preferredLocalizations);
    if (code) {
        return code;
    }

    code = WGCodeFromObject(NSLocale.preferredLanguages);
    return code ?: @"en";
}

BOOL WGCurrentLanguageIsRTL(void) {
    NSString *code = WGCurrentTelegramLanguageCode();
    return [code isEqualToString:@"ar"] || [code isEqualToString:@"fa"];
}

UISemanticContentAttribute WGCurrentSemanticContentAttribute(void) {
    return WGCurrentLanguageIsRTL()
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}

NSTextAlignment WGCurrentTextAlignment(void) {
    return WGCurrentLanguageIsRTL() ? NSTextAlignmentRight : NSTextAlignmentLeft;
}

BOOL WGLocalizationEnabled(void) {
    id explicitValue = [NSUserDefaults.standardUserDefaults objectForKey:WGLocalizationEnabledDefaultsKey];
    return explicitValue ? [explicitValue boolValue] : YES;
}

static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *WGAllTranslationTables(void) {
    static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *tables;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tables = WGGeneratedTranslationTables();
    });
    return tables;
}

static NSSet<NSString *> *WGCanonicalSourceStrings(void) {
    static NSSet<NSString *> *sourceStrings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableSet<NSString *> *keys = [NSMutableSet set];
        [WGAllTranslationTables() enumerateKeysAndObjectsUsingBlock:^(NSString *language,
                                                                      NSDictionary<NSString *, NSString *> *table,
                                                                      BOOL *stop) {
            [keys addObjectsFromArray:table.allKeys];
        }];
        sourceStrings = [keys copy];
    });
    return sourceStrings;
}

static NSDictionary<NSString *, NSString *> *WGCaseInsensitiveCanonicalSourceMap(void) {
    static NSDictionary<NSString *, NSString *> *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionary];
        for (NSString *source in WGCanonicalSourceStrings()) {
            NSString *folded = source.lowercaseString;
            if (!result[folded]) {
                result[folded] = source;
            }
        }
        map = [result copy];
    });
    return map;
}

static NSDictionary<NSString *, NSString *> *WGExactReverseTranslationMap(void) {
    static NSDictionary<NSString *, NSString *> *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionary];
        [WGAllTranslationTables() enumerateKeysAndObjectsUsingBlock:^(NSString *language,
                                                                      NSDictionary<NSString *, NSString *> *table,
                                                                      BOOL *stop) {
            [table enumerateKeysAndObjectsUsingBlock:^(NSString *source,
                                                       NSString *translated,
                                                       BOOL *innerStop) {
                if (translated.length > 0 && !result[translated]) {
                    result[translated] = source;
                }
            }];
        }];
        map = [result copy];
    });
    return map;
}

static NSDictionary<NSString *, NSString *> *WGCaseInsensitiveReverseTranslationMap(void) {
    static NSDictionary<NSString *, NSString *> *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionary];
        [WGExactReverseTranslationMap() enumerateKeysAndObjectsUsingBlock:^(NSString *translated,
                                                                            NSString *source,
                                                                            BOOL *stop) {
            NSString *folded = translated.lowercaseString;
            if (!result[folded]) {
                result[folded] = source;
            }
        }];
        map = [result copy];
    });
    return map;
}

static NSString *WGCanonicalSourceForString(NSString *value) {
    if (value.length == 0) {
        return value;
    }
    if ([WGCanonicalSourceStrings() containsObject:value]) {
        return value;
    }

    NSString *source = WGExactReverseTranslationMap()[value];
    if (source) {
        return source;
    }
    source = WGCaseInsensitiveCanonicalSourceMap()[value.lowercaseString];
    if (source) {
        return source;
    }
    source = WGCaseInsensitiveReverseTranslationMap()[value.lowercaseString];
    return source ?: value;
}

static NSDictionary<NSString *, NSArray<NSArray<NSString *> *> *> *WGDynamicRuleTemplates(void) {
    static NSDictionary<NSString *, NSArray<NSArray<NSString *> *> *> *templates;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        templates = @{
            @"ar": @[
                @[@"^Account \"(.+)\" is already added\\.$", @"الحساب «$1» مضاف مسبقاً."],
                @[@"^Restored accounts: ([0-9]+)$", @"الحسابات المستعادة: $1"],
                @[@"^([0-9]+) account\\(s\\) saved to Keychain$", @"تم حفظ $1 حساب في سلسلة المفاتيح"],
                @[@"^([0-9]+) messages will be restored and visible in the chat again\\.$", @"ستُستعاد $1 رسالة وتظهر مجدداً في المحادثة."],
                @[@"^Font changed: (.+)\\. Restart Whitegram$", @"تم تغيير الخط إلى $1. أعد تشغيل وايت كرام"],
                @[@"^Font selected: (.+)\\. Restart Whitegram$", @"تم اختيار الخط $1. أعد تشغيل وايت كرام"],
                @[@"^Restored ([0-9]+) messages \\(([0-9]+) new\\)\\.$", @"تمت استعادة $1 رسالة ($2 جديدة)."],
                @[@"^Restored ([0-9]+) settings\\. Restart Whitegram$", @"تمت استعادة $1 إعداد. أعد تشغيل وايت كرام"],
                @[@"^Downloading ([0-9]+)%$", @"جارٍ التنزيل $1٪"],
                @[@"^([0-9]+) of ([0-9]+) engines$", @"$1 من أصل $2 محرّك"],
                @[@"^Objects found: ([0-9]+)$", @"العناصر المكتشفة: $1"],
                @[@"^Done: ([0-9]+) messages$", @"تم: $1 رسالة"],
                @[@"^Total messages: ([0-9]+)$", @"إجمالي الرسائل: $1"],
                @[@"^Network error: (.+)$", @"خطأ في الشبكة: $1"],
                @[@"^Selected: (.+)$", @"المحدد: $1"],
                @[@"^Show ([0-9]+) more$", @"إظهار $1 إضافية"],
                @[@"^([0-9]+) msg\\.$", @"$1 رسالة"],
            ],
            @"es": @[
                @[@"^Account \"(.+)\" is already added\\.$", @"La cuenta «$1» ya está añadida."],
                @[@"^Restored accounts: ([0-9]+)$", @"Cuentas restauradas: $1"],
                @[@"^([0-9]+) messages will be restored and visible in the chat again\\.$", @"Se restaurarán $1 mensajes y volverán a ser visibles en el chat."],
                @[@"^Font changed: (.+)\\. Restart Whitegram$", @"Fuente cambiada: $1. Reinicia Whitegram"],
                @[@"^Font selected: (.+)\\. Restart Whitegram$", @"Fuente seleccionada: $1. Reinicia Whitegram"],
                @[@"^Restored ([0-9]+) messages \\(([0-9]+) new\\)\\.$", @"Se restauraron $1 mensajes ($2 nuevos)."],
                @[@"^Restored ([0-9]+) settings\\. Restart Whitegram$", @"Se restauraron $1 ajustes. Reinicia Whitegram"],
                @[@"^Downloading ([0-9]+)%$", @"Descargando $1%"],
                @[@"^([0-9]+) of ([0-9]+) engines$", @"$1 de $2 motores"],
                @[@"^Objects found: ([0-9]+)$", @"Objetos encontrados: $1"],
                @[@"^Done: ([0-9]+) messages$", @"Completado: $1 mensajes"],
                @[@"^Total messages: ([0-9]+)$", @"Mensajes totales: $1"],
                @[@"^Network error: (.+)$", @"Error de red: $1"],
                @[@"^Selected: (.+)$", @"Seleccionado: $1"],
                @[@"^Show ([0-9]+) more$", @"Mostrar $1 más"],
                @[@"^([0-9]+) msg\\.$", @"$1 mens."],
            ],
            @"fa": @[
                @[@"^Account \"(.+)\" is already added\\.$", @"حساب «$1» از قبل اضافه شده است."],
                @[@"^Restored accounts: ([0-9]+)$", @"حساب‌های بازیابی‌شده: $1"],
                @[@"^([0-9]+) messages will be restored and visible in the chat again\\.$", @"$1 پیام بازیابی می‌شود و دوباره در گفتگو دیده خواهد شد."],
                @[@"^Font changed: (.+)\\. Restart Whitegram$", @"قلم به $1 تغییر کرد. وایت‌گرام را دوباره راه‌اندازی کنید"],
                @[@"^Font selected: (.+)\\. Restart Whitegram$", @"قلم $1 انتخاب شد. وایت‌گرام را دوباره راه‌اندازی کنید"],
                @[@"^Restored ([0-9]+) messages \\(([0-9]+) new\\)\\.$", @"$1 پیام بازیابی شد ($2 جدید)."],
                @[@"^Restored ([0-9]+) settings\\. Restart Whitegram$", @"$1 تنظیم بازیابی شد. وایت‌گرام را دوباره راه‌اندازی کنید"],
                @[@"^Downloading ([0-9]+)%$", @"در حال دانلود $1٪"],
                @[@"^([0-9]+) of ([0-9]+) engines$", @"$1 از $2 موتور"],
                @[@"^Objects found: ([0-9]+)$", @"موارد یافت‌شده: $1"],
                @[@"^Done: ([0-9]+) messages$", @"انجام شد: $1 پیام"],
                @[@"^Total messages: ([0-9]+)$", @"مجموع پیام‌ها: $1"],
                @[@"^Network error: (.+)$", @"خطای شبکه: $1"],
                @[@"^Selected: (.+)$", @"انتخاب‌شده: $1"],
                @[@"^Show ([0-9]+) more$", @"نمایش $1 مورد دیگر"],
                @[@"^([0-9]+) msg\\.$", @"$1 پیام"],
            ],
            @"fr": @[
                @[@"^Account \"(.+)\" is already added\\.$", @"Le compte «$1» est déjà ajouté."],
                @[@"^Restored accounts: ([0-9]+)$", @"Comptes restaurés : $1"],
                @[@"^([0-9]+) messages will be restored and visible in the chat again\\.$", @"$1 messages seront restaurés et à nouveau visibles dans la discussion."],
                @[@"^Font changed: (.+)\\. Restart Whitegram$", @"Police modifiée : $1. Redémarrez Whitegram"],
                @[@"^Font selected: (.+)\\. Restart Whitegram$", @"Police sélectionnée : $1. Redémarrez Whitegram"],
                @[@"^Restored ([0-9]+) messages \\(([0-9]+) new\\)\\.$", @"$1 messages restaurés ($2 nouveaux)."],
                @[@"^Restored ([0-9]+) settings\\. Restart Whitegram$", @"$1 réglages restaurés. Redémarrez Whitegram"],
                @[@"^Downloading ([0-9]+)%$", @"Téléchargement $1 %"],
                @[@"^([0-9]+) of ([0-9]+) engines$", @"$1 sur $2 moteurs"],
                @[@"^Objects found: ([0-9]+)$", @"Objets trouvés : $1"],
                @[@"^Done: ([0-9]+) messages$", @"Terminé : $1 messages"],
                @[@"^Total messages: ([0-9]+)$", @"Total des messages : $1"],
                @[@"^Network error: (.+)$", @"Erreur réseau : $1"],
                @[@"^Selected: (.+)$", @"Sélectionné : $1"],
                @[@"^Show ([0-9]+) more$", @"Afficher $1 de plus"],
                @[@"^([0-9]+) msg\\.$", @"$1 msg."],
            ],
            @"pt": @[
                @[@"^Account \"(.+)\" is already added\\.$", @"A conta «$1» já foi adicionada."],
                @[@"^Restored accounts: ([0-9]+)$", @"Contas restauradas: $1"],
                @[@"^([0-9]+) messages will be restored and visible in the chat again\\.$", @"$1 mensagens serão restauradas e voltarão a ficar visíveis no chat."],
                @[@"^Font changed: (.+)\\. Restart Whitegram$", @"Fonte alterada: $1. Reinicie o Whitegram"],
                @[@"^Font selected: (.+)\\. Restart Whitegram$", @"Fonte selecionada: $1. Reinicie o Whitegram"],
                @[@"^Restored ([0-9]+) messages \\(([0-9]+) new\\)\\.$", @"$1 mensagens restauradas ($2 novas)."],
                @[@"^Restored ([0-9]+) settings\\. Restart Whitegram$", @"$1 ajustes restaurados. Reinicie o Whitegram"],
                @[@"^Downloading ([0-9]+)%$", @"Baixando $1%"],
                @[@"^([0-9]+) of ([0-9]+) engines$", @"$1 de $2 mecanismos"],
                @[@"^Objects found: ([0-9]+)$", @"Objetos encontrados: $1"],
                @[@"^Done: ([0-9]+) messages$", @"Concluído: $1 mensagens"],
                @[@"^Total messages: ([0-9]+)$", @"Total de mensagens: $1"],
                @[@"^Network error: (.+)$", @"Erro de rede: $1"],
                @[@"^Selected: (.+)$", @"Selecionado: $1"],
                @[@"^Show ([0-9]+) more$", @"Mostrar mais $1"],
                @[@"^([0-9]+) msg\\.$", @"$1 msg."],
            ],
        };
    });
    return templates;
}

static NSString *WGApplyDynamicRules(NSString *canonicalInput, NSString *languageCode) {
    NSArray<NSArray<NSString *> *> *rules = WGDynamicRuleTemplates()[languageCode];
    if (rules.count == 0) {
        return canonicalInput;
    }

    NSRange fullRange = NSMakeRange(0, canonicalInput.length);
    for (NSArray<NSString *> *rule in rules) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:rule[0]
                                                                              options:0
                                                                                error:nil];
        if ([regex firstMatchInString:canonicalInput options:0 range:fullRange]) {
            return [regex stringByReplacingMatchesInString:canonicalInput
                                                   options:0
                                                     range:fullRange
                                              withTemplate:rule[1]];
        }
    }
    return canonicalInput;
}

NSString *WGTranslateString(NSString *input) {
    if (!WGLocalizationEnabled() || input.length == 0) {
        return input;
    }

    NSCharacterSet *trimSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSUInteger start = 0;
    while (start < input.length && [trimSet characterIsMember:[input characterAtIndex:start]]) {
        start++;
    }

    NSUInteger end = input.length;
    while (end > start && [trimSet characterIsMember:[input characterAtIndex:end - 1]]) {
        end--;
    }

    NSString *prefix = [input substringToIndex:start];
    NSString *core = [input substringWithRange:NSMakeRange(start, end - start)];
    NSString *suffix = [input substringFromIndex:end];
    NSString *canonical = WGCanonicalSourceForString(core);

    static NSDictionary<NSString *, NSString *> *englishAliases;
    static dispatch_once_t aliasOnceToken;
    dispatch_once(&aliasOnceToken, ^{
        englishAliases = @{
            @"Найти опцию...": @"Find option...",
            @"Поиск настроек": @"Search settings",
        };
    });
    canonical = englishAliases[canonical] ?: canonical;

    NSString *languageCode = WGCurrentTelegramLanguageCode();
    NSString *translated = canonical;
    if (![languageCode isEqualToString:@"en"]) {
        translated = WGAllTranslationTables()[languageCode][canonical];
        if (!translated && canonical.length > 1) {
            unichar last = [canonical characterAtIndex:canonical.length - 1];
            if (last == ':' || last == '?' || last == '!' || last == '.') {
                NSString *base = [canonical substringToIndex:canonical.length - 1];
                NSString *baseTranslation = WGAllTranslationTables()[languageCode][base];
                if (baseTranslation) {
                    translated = [baseTranslation stringByAppendingString:[canonical substringFromIndex:canonical.length - 1]];
                }
            }
        }
        if (!translated) {
            translated = WGApplyDynamicRules(canonical, languageCode);
        }
        if (!translated) {
            translated = canonical;
        }
    }

    if ([translated isEqualToString:core]) {
        return input;
    }
    return [NSString stringWithFormat:@"%@%@%@", prefix, translated, suffix];
}

NSAttributedString *WGTranslateAttributedString(NSAttributedString *input) {
    if (!WGLocalizationEnabled() || input.length == 0) {
        return input;
    }

    NSString *translated = WGTranslateString(input.string);
    if ([translated isEqualToString:input.string]) {
        return input;
    }

    /* Preserve the exact attribute dictionary. Do not inject paragraph styles
       into Telegram/Texture text nodes; doing that can invalidate their layout. */
    NSDictionary<NSAttributedStringKey, id> *attributes = input.length > 0
        ? ([input attributesAtIndex:0 effectiveRange:nil] ?: @{})
        : @{};
    return [[NSAttributedString alloc] initWithString:translated attributes:attributes];
}
