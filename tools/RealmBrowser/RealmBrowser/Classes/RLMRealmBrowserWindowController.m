////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMRealmBrowserWindowController.h"
#import "NSTableColumn+Resize.h"
#import "RLMNavigationStack.h"

@interface RLMRealm (Dynamic)
- (RLMArray *)objects:(NSString *)className where:(NSString *)predicateFormat, ...;
@end

@interface RLMArray (Private)
- (instancetype)initWithObjectClassName:(NSString *)objectClassName;
@end

const NSUInteger kMaxNumberOfArrayEntriesInToolTip = 5;

@implementation RLMRealmBrowserWindowController {

    RLMNavigationStack *navigationStack;
}

#pragma mark - NSViewController overrides

- (void)windowDidLoad
{
    navigationStack = [[RLMNavigationStack alloc] init];
    [self updateNavigationButtons];
    
    id firstItem = self.modelDocument.presentedRealm.topLevelClazzes.firstObject;
    if (firstItem != nil) {
        RLMNavigationState *initState = [[RLMNavigationState alloc] initWithSelectedType:firstItem
                                                                                   index:0];

        [self addNavigationState:initState
              fromViewController:nil];
    }
}

#pragma mark - Public methods - Accessors

- (RLMNavigationState *)currentState
{
    return navigationStack.currentState;
}

#pragma mark - Public methods

- (void)addNavigationState:(RLMNavigationState *)state fromViewController:(RLMViewController *)controller
{
    if (!controller.navigationFromHistory) {
        RLMNavigationState *oldState = navigationStack.currentState;
        
        [navigationStack pushState:state];
        [self updateNavigationButtons];
        
        if (controller == self.tableViewController || controller == nil) {
            [self.outlineViewController updateUsingState:state
                                                oldState:oldState];
        }
        
        [self.tableViewController updateUsingState:state
                                          oldState:oldState];
    }

    // Searching is not implemented for link arrays yet
    BOOL isArray = [state isMemberOfClass:[RLMArrayNavigationState class]];
    [self.searchField setEnabled:!isArray];
}

- (IBAction)searchAction:(NSSearchFieldCell *)searchCell
{
    NSString *searchText = searchCell.stringValue;
    RLMTypeNode *typeNode = navigationStack.currentState.selectedType;

    // Return to parent class (showing all objects) when the user clears the search text
    if (searchText.length == 0) {
        if ([navigationStack.currentState isMemberOfClass:[RLMQueryNavigationState class]]) {
            RLMNavigationState *state = [[RLMNavigationState alloc] initWithSelectedType:typeNode index:0];
            [self addNavigationState:state fromViewController:self.tableViewController];
        }
        return;
    }

    NSArray *columns = typeNode.propertyColumns;
    NSUInteger columnCount = columns.count;
    RLMRealm *realm = self.modelDocument.presentedRealm.realm;

    NSString *predicate = @"";

    for (NSUInteger index = 0; index < columnCount; index++) {

        RLMClazzProperty *property = columns[index];
        NSString *columnName = property.name;

        switch (property.type) {
            case RLMPropertyTypeBool: {
                if ([searchText caseInsensitiveCompare:@"true"] == NSOrderedSame ||
                    [searchText caseInsensitiveCompare:@"YES"] == NSOrderedSame) {
                    if (predicate.length != 0) {
                        predicate = [predicate stringByAppendingString:@" OR "];
                    }
                    predicate = [predicate stringByAppendingFormat:@"%@ = YES", columnName];
                }
                else if ([searchText caseInsensitiveCompare:@"false"] == NSOrderedSame ||
                         [searchText caseInsensitiveCompare:@"NO"] == NSOrderedSame) {
                    if (predicate.length != 0) {
                        predicate = [predicate stringByAppendingString:@" OR "];
                    }
                    predicate = [predicate stringByAppendingFormat:@"%@ = NO", columnName];
                }
                break;
            }
            case RLMPropertyTypeInt: {
                int value;
                if ([searchText isEqualToString:@"0"]) {
                    value = 0;
                }
                else {
                    value = [searchText intValue];
                    if (value == 0)
                        break;
                }

                if (predicate.length != 0) {
                    predicate = [predicate stringByAppendingString:@" OR "];
                }
                predicate = [predicate stringByAppendingFormat:@"%@ = %d", columnName, (int)value];
                break;
            }
            case RLMPropertyTypeString: {
                if (predicate.length != 0) {
                    predicate = [predicate stringByAppendingString:@" OR "];
                }
                predicate = [predicate stringByAppendingFormat:@"%@ CONTAINS '%@'", columnName, searchText];
                break;
            }
            //case RLMPropertyTypeFloat: // search on float columns disabled until bug is fixed in binding
            case RLMPropertyTypeDouble:
            {
                double value;

                if ([searchText isEqualToString:@"0"] ||
                    [searchText isEqualToString:@"0.0"]) {
                    value = 0.0;
                }
                else {
                    value = [searchText doubleValue];
                    if (value == 0.0)
                        break;
                }

                if (predicate.length != 0) {
                    predicate = [predicate stringByAppendingString:@" OR "];
                }
                predicate = [predicate stringByAppendingFormat:@"%@ = %f", columnName, value];
                break;
            }
            default:
                break;
        }
    }

    RLMArray *result;
    if (predicate.length != 0) {
        result = [realm objects:typeNode.name where:predicate];
    }
    else {
        result = [[RLMArray alloc] initWithObjectClassName:typeNode.name];
    }

    RLMQueryNavigationState *state = [[RLMQueryNavigationState alloc] initWithQuery:searchText type:typeNode results:result];
    [self addNavigationState:state fromViewController:self.tableViewController];
}

- (IBAction)userClicksOnNavigationButtons:(NSSegmentedControl *)buttons
{
    RLMNavigationState *oldState = navigationStack.currentState;
    
    switch (buttons.selectedSegment) {
        case 0: { // Navigate backwards
            RLMNavigationState *state = [navigationStack navigateBackward];
            if (state != nil) {
                [self.outlineViewController updateUsingState:state
                                                       oldState:oldState];
                [self.tableViewController updateUsingState:state
                                                     oldState:oldState];
            }
            break;
        }
        case 1: { // Navigate backwards
            RLMNavigationState *state = [navigationStack navigateForward];
            if (state != nil) {
                [self.outlineViewController updateUsingState:state
                                                       oldState:oldState];
                [self.tableViewController updateUsingState:state
                                                     oldState:oldState];
            }
            break;
        }
        default:
            break;
    }
    
    [self updateNavigationButtons];    
}

#pragma mark - Private methods

- (void)updateNavigationButtons
{
    [self.navigationButtons setEnabled:[navigationStack canNavigateBackward]
                            forSegment:0];
    [self.navigationButtons setEnabled:[navigationStack canNavigateForward]
                            forSegment:1];
}

@end
