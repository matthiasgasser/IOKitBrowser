//
//  ELLViewController.m
//  IOKitTest
//
//  Created by Christopher Anderson on 26/12/2013.
//  Copyright (c) 2013 Electric Labs. All rights reserved.
//

#import "ELLViewController.h"
#import "ELLIOKitNodeInfo.h"
#import "ELLIOKitDumper.h"

@interface ELLViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property(nonatomic, strong) ELLIOKitNodeInfo *root;
@property(nonatomic, strong) ELLIOKitNodeInfo *locationInTree;

@property(nonatomic, strong) IBOutlet UITableView *tableView;
@property(nonatomic, strong) IBOutlet UIActivityIndicatorView *spinner;
@property(nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property(nonatomic, strong) IBOutlet UILabel *trailLabel;
@property(nonatomic, strong) IBOutlet UIView *trailHolder;

@property(nonatomic, strong) NSMutableArray *trailStack;
@property(nonatomic, strong) NSMutableArray *offsetStack;

@property(nonatomic, copy) NSString *searchTerm;

@property(nonatomic, strong) NSTimer *searchDelayTimer;

@property(nonatomic, strong) ELLIOKitDumper *dumper;
@end

@implementation ELLViewController

static NSString *kSearchTerm = @"kSearchTerm";

- (void)awakeFromNib {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];

    self.dumper = [ELLIOKitDumper new];
    [super awakeFromNib];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_searchDelayTimer invalidate];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self _loadIOKit];
}

- (void)_loadIOKit {
    _tableView.hidden = YES;
    _trailHolder.hidden = YES;
    [_spinner startAnimating];

    self.trailStack = [NSMutableArray new];
    self.offsetStack = [NSMutableArray new];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.root = [_dumper dumpIOKitTree];
        self.locationInTree = _root;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_trailStack addObject:_root.name];
            [self _setupTrail];
            [_tableView reloadData];

            _tableView.hidden = NO;
            _trailHolder.hidden = NO;
            [_spinner stopAnimating];
        });
    });
}

- (NSAttributedString *)_stringForTrail:(NSArray *)stack {
    return [[NSAttributedString alloc] initWithString:[stack componentsJoinedByString:@" > "]];
}

- (IBAction)moveBack:(id)sender {
    if (_locationInTree.parent) {
        _locationInTree = _locationInTree.parent;
        [_trailStack removeLastObject];

        [_tableView reloadData];

        CGPoint contentOffset = [[_offsetStack lastObject] CGPointValue];
        _tableView.contentOffset = contentOffset;
        [_offsetStack removeLastObject];

        [self _setupTrail];
    }
}

- (void)_setupTrail {
    _trailLabel.attributedText = [self _stringForTrail:_trailStack];
}

- (NSInteger)_searchForTerm:(NSString *)searchTerm inSubTree:(ELLIOKitNodeInfo *)subTree {
    __block NSInteger searchCount = 0;

    if ([subTree.name rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound) {
        searchCount++;
    }


    NSMutableArray *matchingProperties = [NSMutableArray new];

    [subTree.properties enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
        if ([obj rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound) {
            searchCount++;
            [matchingProperties addObject:obj];
        }
    }];


    NSMutableArray *matchedChildren = [NSMutableArray new];

    for (ELLIOKitNodeInfo *child in subTree.children) {
        NSInteger preThisPropertySearchCount = searchCount;
        searchCount += [self _searchForTerm:searchTerm inSubTree:child];
        if (searchCount > preThisPropertySearchCount) {
            [matchedChildren addObject:child];
        }
    }

    subTree.matchingProperties = matchingProperties;
    subTree.matchedChildren = matchedChildren;
    return subTree.searchCount = searchCount;
}

#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [[self _propertiesForLocation] count];
    } else {
        return [[self _childrenForLocation] count];
    }

}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [[self _propertiesForLocation] count] ? @"Properties" : @"";
    } else {
        return [[self _childrenForLocation] count] ? @"Children" : @"";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"ELLViewControllerCellPropertiesIdentifier";

    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:14.0f];
    }

    NSString *cellText = @"";
    if (indexPath.section == 0) {
        cellText = [self _propertiesForLocation][indexPath.row];

        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        ELLIOKitNodeInfo *childNode = [self _childrenForLocation][indexPath.row];

        cellText = [NSString stringWithFormat:@"%@ %@", childNode.name,
                                              childNode.searchCount ? [NSString stringWithFormat:@"[%li]", (long) childNode.searchCount] : @""];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }


    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:cellText];
    [self _highlightSearchTerm:_searchTerm inText:text];
    cell.textLabel.attributedText = text;

    return cell;
}

- (void)_highlightSearchTerm:(NSString *)searchTerm inText:(NSMutableAttributedString *)text {
    if (searchTerm.length) {
        NSDictionary *attrs = @{NSFontAttributeName : [UIFont boldSystemFontOfSize:14.0f]};

        NSRange range = [text.string rangeOfString:searchTerm options:NSCaseInsensitiveSearch];
        while (range.location != NSNotFound) {
            [text setAttributes:attrs range:range];
            range = [text.string rangeOfString:searchTerm
                                       options:NSCaseInsensitiveSearch
                                         range:NSMakeRange(range.location + 1, [text length] - range.location - 1)];
        }

    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *attributes = @{NSFontAttributeName : [UIFont systemFontOfSize:14.0f]};

    CGRect textBounds = CGRectZero;

    if (indexPath.section == 0) {
        NSString *value = [self _propertiesForLocation][indexPath.row];
        textBounds = [value boundingRectWithSize:CGSizeMake(CGRectGetWidth(_tableView.bounds), MAXFLOAT)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:attributes
                                         context:nil];
    } else {
        ELLIOKitNodeInfo *childNode = [self _childrenForLocation][indexPath.row];
        textBounds = [childNode.name boundingRectWithSize:CGSizeMake(CGRectGetWidth(_tableView.bounds), MAXFLOAT)
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                               attributes:attributes
                                                  context:nil];

    }

    return MIN(MAX(40.0f, textBounds.size.height + 10.0f), 300.0f);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        [_searchBar resignFirstResponder];

        ELLIOKitNodeInfo *childNode = [self _childrenForLocation][indexPath.row];

        self.locationInTree = childNode;

        [_trailStack addObject:_locationInTree.name];
        [_offsetStack addObject:[NSValue valueWithCGPoint:_tableView.contentOffset]];
        _tableView.contentOffset = CGPointZero;


        [self _setupTrail];

        [tableView reloadData];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [_searchBar resignFirstResponder];
}

#pragma mark Helpers

- (NSArray *)_propertiesForLocation {
    return _searchTerm.length ? _locationInTree.matchingProperties : _locationInTree.properties;
}

- (NSArray *)_childrenForLocation {
    return (_searchTerm.length ? _locationInTree.matchedChildren : _locationInTree.children);
}

#pragma mark UISearchBar

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchTerm {
    [_searchDelayTimer invalidate];
    self.searchDelayTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(_searchWithTimer:)
                                                           userInfo:@{kSearchTerm : searchTerm}
                                                            repeats:NO];
}

- (void)_searchWithTimer:(NSTimer *)timer {
    NSString *searchTerm = timer.userInfo[kSearchTerm];
    self.searchTerm = searchTerm;
    [self _searchForTerm:searchTerm inSubTree:_root];
    [_tableView reloadData];
}

#pragma mark Keyboard

- (void)keyboardWasShown:(NSNotification *)aNotification {
    NSDictionary *info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;

    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    _tableView.contentInset = contentInsets;
    _tableView.scrollIndicatorInsets = contentInsets;

}

- (void)keyboardWillBeHidden:(NSNotification *)aNotification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    _tableView.contentInset = contentInsets;
    _tableView.scrollIndicatorInsets = contentInsets;
}
@end
