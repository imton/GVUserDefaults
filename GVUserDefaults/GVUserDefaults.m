//
//  GVUserDefaults.m
//  GVUserDefaults
//
//  Created by Kevin Renskers on 18-12-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import "GVUserDefaults.h"
#import <objc/runtime.h>

@interface GVUserDefaults ()
@property (strong, nonatomic) NSMutableDictionary *mapping;
@end

@implementation GVUserDefaults

enum TypeEncodings {
    Char                = 'c',
    Bool                = 'B',
    Short               = 's',
    Int                 = 'i',
    Long                = 'l',
    LongLong            = 'q',
    UnsignedChar        = 'C',
    UnsignedShort       = 'S',
    UnsignedInt         = 'I',
    UnsignedLong        = 'L',
    UnsignedLongLong    = 'Q',
    Float               = 'f',
    Double              = 'd',
    Object              = '@'
};

- (NSString *)defaultsKeyForPropertyNamed:(char const *)propertyName {
    NSString *key = [NSString stringWithFormat:@"%s", propertyName];
    return [self _transformKey:key];
}

- (NSString *)defaultsKeyForSelector:(SEL)selector {
    return [self.mapping objectForKey:NSStringFromSelector(selector)];
}

static long long longLongGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [[[NSUserDefaults standardUserDefaults] objectForKey:key] longLongValue];
}

static void longLongSetter(GVUserDefaults *self, SEL _cmd, long long value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    NSNumber *object = [NSNumber numberWithLongLong:value];
    [[NSUserDefaults standardUserDefaults] setObject:object forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];    
}

static bool boolGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static void boolSetter(GVUserDefaults *self, SEL _cmd, bool value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];    
}

static int integerGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return (int)[[NSUserDefaults standardUserDefaults] integerForKey:key];
}

static void integerSetter(GVUserDefaults *self, SEL _cmd, int value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];    
}

static float floatGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [[NSUserDefaults standardUserDefaults] floatForKey:key];
}

static void floatSetter(GVUserDefaults *self, SEL _cmd, float value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];    
}

static double doubleGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [[NSUserDefaults standardUserDefaults] doubleForKey:key];
}

static void doubleSetter(GVUserDefaults *self, SEL _cmd, double value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    [[NSUserDefaults standardUserDefaults] setDouble:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];    
}

static id objectGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

static void objectSetter(GVUserDefaults *self, SEL _cmd, id object) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    if (object) {
        [[NSUserDefaults standardUserDefaults] setObject:object forKey:key];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];    
}

#pragma mark - Begin

+ (instancetype)standardUserDefaults {
    static dispatch_once_t pred;
    static GVUserDefaults *sharedInstance = nil;
    dispatch_once(&pred, ^{ sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma GCC diagnostic ignored "-Warc-performSelector-leaks"

- (id)init {
    self = [super init];
    if (self) {
        SEL setupDefaultSEL = NSSelectorFromString([NSString stringWithFormat:@"%@pDefaults", @"setu"]);
        if ([self respondsToSelector:setupDefaultSEL]) {
            NSDictionary *defaults = [self performSelector:setupDefaultSEL];
            NSMutableDictionary *mutableDefaults = [NSMutableDictionary dictionaryWithCapacity:[defaults count]];
            for (NSString *key in defaults) {
                id value = [defaults objectForKey:key];
                NSString *transformedKey = [self _transformKey:key];
                [mutableDefaults setObject:value forKey:transformedKey];
            }
            [[NSUserDefaults standardUserDefaults] registerDefaults:mutableDefaults];
        }

        [self generateAccessorMethods];
    }

    return self;
}

- (NSString *)_transformKey:(NSString *)key {
    if ([self respondsToSelector:@selector(transformKey:)]) {
        return [self performSelector:@selector(transformKey:) withObject:key];
    }

    return key;
}

#pragma GCC diagnostic pop

- (void)generateAccessorMethods {
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList([self class], &count);

    self.mapping = [NSMutableDictionary dictionary];

    for (int i = 0; i < count; ++i) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);
        const char *attributes = property_getAttributes(property);

        char *getter = strstr(attributes, ",G");
        if (getter) {
            getter = strdup(getter + 2);
            getter = strsep(&getter, ",");
        } else {
            getter = strdup(name);
        }
        SEL getterSel = sel_registerName(getter);
        free(getter);

        char *setter = strstr(attributes, ",S");
        if (setter) {
            setter = strdup(setter + 2);
            setter = strsep(&setter, ",");
        } else {
            asprintf(&setter, "set%c%s:", toupper(name[0]), name + 1);
        }
        SEL setterSel = sel_registerName(setter);
        free(setter);

        NSString *key = [self defaultsKeyForPropertyNamed:name];
        [self.mapping setValue:key forKey:NSStringFromSelector(getterSel)];
        [self.mapping setValue:key forKey:NSStringFromSelector(setterSel)];

        IMP getterImp = NULL;
        IMP setterImp = NULL;
        char type = attributes[1];
        switch (type) {
            case Short:
            case Long:
            case LongLong:
            case UnsignedChar:
            case UnsignedShort:
            case UnsignedInt:
            case UnsignedLong:
            case UnsignedLongLong:
                getterImp = (IMP)longLongGetter;
                setterImp = (IMP)longLongSetter;
                break;

            case Bool:
            case Char:
                getterImp = (IMP)boolGetter;
                setterImp = (IMP)boolSetter;
                break;

            case Int:
                getterImp = (IMP)integerGetter;
                setterImp = (IMP)integerSetter;
                break;

            case Float:
                getterImp = (IMP)floatGetter;
                setterImp = (IMP)floatSetter;
                break;

            case Double:
                getterImp = (IMP)doubleGetter;
                setterImp = (IMP)doubleSetter;
                break;

            case Object:
                getterImp = (IMP)objectGetter;
                setterImp = (IMP)objectSetter;
                break;

            default:
                free(properties);
                [NSException raise:NSInternalInconsistencyException format:@"Unsupported type of property \"%s\" in class %@", name, self];
                break;
        }

        char types[5];

        snprintf(types, 4, "%c@:", type);
        class_addMethod([self class], getterSel, getterImp, types);
        
        snprintf(types, 5, "v@:%c", type);
        class_addMethod([self class], setterSel, setterImp, types);
    }

    free(properties);
}

@end
