//
// Created by hivehicks on 10.05.12.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "HHUnitConverter.h"
#import "PESGraph.h"
#import "PESGraphNode.h"
#import "PESGraphEdge.h"
#import "PESGraphRoute.h"
#import "PESGraphRouteStep.h"

HHConversionRule HHConversionRuleMake(double multiplier, double summand, BOOL sumafter)
{
    HHConversionRule rule;
    rule.multiplier = multiplier;
    rule.sumafter = sumafter;
    rule.summand = summand;
    return rule;
}

HHConversionRule HHConversionRuleMakeInverse(HHConversionRule rule)
{
    return HHConversionRuleMake(1 / rule.multiplier, -rule.summand / rule.multiplier, rule.sumafter);
}

HHConversionRule HHConversionRuleMakeFromNSValue(NSValue *value)
{
    HHConversionRule rule;
    [value getValue:&rule];
    return rule;
}

NSValue *HHConversionRuleToNSValue(HHConversionRule rule)
{
    return [NSValue value:&rule withObjCType:@encode(HHConversionRule)];
}


@implementation HHUnitConverter {
    PESGraph *_graph;
    NSMutableDictionary *_weights;
}

- (id)init
{
    if (self = [super init]) {
        _graph = [PESGraph new];
        _weights = [NSMutableDictionary new];
    }
    return self;
}

- (void)setConversionRule:(HHConversionRule)rule fromUnit:(NSString *)srcUnit toUnit:(NSString *)targetUnit
{
    PESGraphNode *node1 = [_graph nodeInGraphWithIdentifier:srcUnit];
    if (node1 == nil) {
        node1 = [PESGraphNode nodeWithIdentifier:srcUnit];
    }

    PESGraphNode *node2 = [_graph nodeInGraphWithIdentifier:targetUnit];
    if (node2 == nil) {
        node2 = [PESGraphNode nodeWithIdentifier:targetUnit];
    }

    NSString *directName = [NSString stringWithFormat:@"%@->%@", srcUnit, targetUnit];
    [_graph addEdge:[PESGraphEdge edgeWithName:directName] fromNode:node1 toNode:node2];
    [_weights setObject:HHConversionRuleToNSValue(rule) forKey:directName];
    
    NSString *inverseName = [NSString stringWithFormat:@"%@->%@", targetUnit, srcUnit];
    if (!_weights[inverseName]) {
        [_graph addEdge:[PESGraphEdge edgeWithName:inverseName] fromNode:node2 toNode:node1];
        [_weights setObject:HHConversionRuleToNSValue(HHConversionRuleMakeInverse(rule)) forKey:inverseName];
    }
}

- (void)letUnit:(NSString *)srcUnit convertToUnit:(NSString *)targetUnit byMultiplyingBy:(double)multiplier
{
    [self letUnit:srcUnit convertToUnit:targetUnit byMultiplyingBy:multiplier andAdding:0];
}

- (void)letUnit:(NSString *)srcUnit convertToUnit:(NSString *)targetUnit byAdding:(double)summand
{
    [self letUnit:srcUnit convertToUnit:targetUnit byMultiplyingBy:1 andAdding:summand];
}

- (void)letUnit:(NSString *)srcUnit convertToUnit:(NSString *)targetUnit byMultiplyingBy:(double)multiplier andAdding:(double)summand
{
    [self setConversionRule:HHConversionRuleMake(multiplier, summand, YES) fromUnit:srcUnit toUnit:targetUnit];
}

- (void)letUnit:(NSString *)srcUnit convertToUnit:(NSString *)targetUnit byMultiplyingBy:(double)multiplier andAdding:(double)summand after:(BOOL)after
{
    [self setConversionRule:HHConversionRuleMake(multiplier, summand, after) fromUnit:srcUnit toUnit:targetUnit];
}

- (NSNumber *)value:(double)value convertedFromUnit:(NSString *)srcUnit toUnit:(NSString *)targetUnit
{
    if ([srcUnit isEqualToString:targetUnit]) {
        return [NSNumber numberWithDouble:value];
    }

    NSArray *srcUnitComps = [srcUnit componentsSeparatedByString:@"/"];
    NSArray *targetUnitComps = [targetUnit componentsSeparatedByString:@"/"];
    if (srcUnitComps.count != targetUnitComps.count) {
        return nil;
    }

    if (srcUnitComps.count == 2)
    {
        NSString *srcNumeratorUnit = [srcUnitComps objectAtIndex:0];
        NSString *srcDenominatorUnit = [srcUnitComps objectAtIndex:1];
        NSString *targetNumeratorUnit = [targetUnitComps objectAtIndex:0];
        NSString *targetDenominatorUnit = [targetUnitComps objectAtIndex:1];

        NSNumber *kNumerator = [self value:value convertedFromUnit:srcNumeratorUnit toUnit:targetNumeratorUnit];
        NSNumber *kDenominator = [self value:1 convertedFromUnit:srcDenominatorUnit toUnit:targetDenominatorUnit];

        if (kNumerator && kDenominator) {
            double result = [kNumerator doubleValue] / [kDenominator doubleValue];
            return [NSNumber numberWithDouble:result];
        }
    }
    else
    {
        NSArray *rules = [self _conversionRulesFromUnit:srcUnit toUnit:targetUnit];
        if (rules) {
            return [NSNumber numberWithDouble:[self _valueByApplyingConversionRules:rules toValue:value]];
        }
    }

    return nil;
}

#pragma mark -
#pragma mark Private

- (NSArray *)_conversionRulesFromUnit:(NSString *)srcUnit toUnit:(NSString *)targetUnit
{
    NSMutableArray *rules = [NSMutableArray new];

    PESGraphNode *srcNode = [_graph nodeInGraphWithIdentifier:srcUnit];
    PESGraphNode *targetNode = [_graph nodeInGraphWithIdentifier:targetUnit];

    if (srcNode && targetNode) {
        PESGraphRoute *route = [_graph shortestRouteFromNode:srcNode toNode:targetNode];
        if (route) {
            for (PESGraphRouteStep *routeStep in route.steps) {
                if (routeStep.edge) {
                    [rules addObject:[_weights objectForKey:routeStep.edge.name]];
                }
            }
            return [[rules reverseObjectEnumerator] allObjects];
        }
    }

    return nil;
}

- (double)_valueByApplyingConversionRules:(NSArray *)rules toValue:(double)value
{
    double result = value;
    
    HHConversionRule rule;
    for (int i = 0; i < rules.count; i ++) {
        rule = HHConversionRuleMakeFromNSValue(rules[i]);
        
        if (!rule.sumafter) {
            result += rule.summand;
        }
        
        result *= rule.multiplier;
        
        if (rule.sumafter) {
            result += rule.summand;
        }
    }
    
    return result;
}

@end
