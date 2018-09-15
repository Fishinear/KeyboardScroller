//
//  KeyboardScroller.m
//  Flyskyhy
//
//  Created by René Dekker on 2017-11-19.
//  Copyright © 2017-2018 Renevision. All rights reserved.
//

#import "KeyboardScroller.h"
#import <UIKit/UIKit.h>

// Sequence of notifications that arrive as result of different kinds of actions
//
// Action               iPhone 4S iOS-8         iPhone 7+ iOS-10    iPhone X iOS-11
//
// select field         fS-kS-wL                fS-kS               fS-kS
// deselect field       kH-fD                   kH-fD               kH-fD
// change field         fD-fS-wL                fD-fS-kS            fD-fS
// rotate phone         wL-kHo-kSn-kHn-kSn      kHo-wL-kSn-kSn      wL-kHo-kSn-kSn
// change keyboard      kS                      kS                  kS
// hide enclosing view  fD                      fD-kH               fD-kH
//
// Explanation for abbreviations:
//
// fS  - fieldSelected (UITextFieldTextDidBeginEditingNotification)
// fD  - fieldDeselected (UITextFieldTextDidEndEditingNotification)
// kS  - keyboardWillShow (UIKeyboardWillShowNotification)
// kH  - keyboardWillHide (UIKeyboardWillHideNotification)
// wL  - viewcontroller.willLayout (possibly leading to a change in contentInset)
//
// As far as we can see, UIKeyboardWillChangeFrameNotification will always and only be sent directly before a Show or Hide notification,
// and at least a Show notification is always sent, even if we only change keyboard size/type. That makes it easier
// to ignore the ChangeFrame notification than to support it directly.

@interface UITextField (DoneExtension)
    - (void) done;
@end
@implementation UITextField (DoneExtension)
    - (void) done
    {
        [self endEditing:YES];
    }
@end

@implementation KeyboardScroller {
    UITextField *selectedField;
    UIScrollView *currentScrollView;
    bool oldPagingEnabled;
    UIEdgeInsets originalInsets;
    UIEdgeInsets requiredInsets;
    UINavigationItem *navigationItem;
    UIGestureRecognizer *gesture;
}

- (void) done
{
    [selectedField endEditing:YES];
}

- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                        context:(void *)context
{
    // In iOS-8, when selecting another field, the view layout logic is called. This may set
    // the contentInset to an incorrect value, because it does not take the keyboard into account.
    // If that happens, then we need to change it back to what is needed for the keyboard.
    UIScrollView *scrollView = (UIScrollView *) object;
    UIEdgeInsets insets = scrollView.contentInset;
    if (!UIEdgeInsetsEqualToEdgeInsets(requiredInsets, insets)) {
        currentScrollView.contentInset = requiredInsets;
    }
}

- (UIToolbar *) createNumberToolbarForField:(UITextField *)field
{
    UIToolbar *numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    numberToolbar.barStyle = UIBarStyleDefault;
    numberToolbar.items = @[
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:field action:@selector(done)]
                            ];
    numberToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    numberToolbar.tintColor = [[UIApplication sharedApplication] keyWindow].tintColor;
    [numberToolbar sizeToFit];
    return numberToolbar;
}

- (void) setField:(UITextField *)field
{
    if (field == selectedField) {
        return;
    }
    selectedField = nil;
    if (field != nil) {
        // if it is not a normal keyboard, and we have not added a Done button to the navigation bar
        // then add a toolbar with Done button to the keyboard
        if (navigationItem == nil &&
            field.keyboardType != UIKeyboardTypeDefault &&
            field.inputAccessoryView == nil)
        {
            field.inputAccessoryView = [self createNumberToolbarForField:field];
        }
        UIScrollView *view = [self findEnclosingScrollView:field];
        if (view == nil) {
            // the new field is not enclosed in a scroll view, ignore it
            [self detachScrollView];
            return;
        }
        selectedField = field;
        [self attachScrollView:view];
    }
}

- (void) attachScrollView:(UIScrollView *)scrollView
{
    if (scrollView == currentScrollView) {
        return;
    }
    [self detachScrollView];
    if (scrollView == nil) {
        return;
    }
    oldPagingEnabled = scrollView.pagingEnabled;
    if (scrollView.pagingEnabled) {
        scrollView.pagingEnabled = NO;
        scrollView.scrollEnabled = NO;
    }
    // make sure that the keyboard is dismissed if we tap on the scrollview outside a field
    if (![scrollView.gestureRecognizers containsObject:gesture]) {
        [scrollView addGestureRecognizer:gesture];
    }
    originalInsets = scrollView.contentInset;
    // if the delegate is a uiviewcontroller with a navigation bar, then add a "Done" button
    // to its right spot if it is empty
    if ([scrollView.delegate isKindOfClass:[UIViewController class]]) {
        UIViewController *controller = (UIViewController *) scrollView.delegate;
        if (controller.navigationController != nil && controller.navigationItem != nil &&
            controller.navigationItem.rightBarButtonItem == nil)
        {
            navigationItem = controller.navigationItem;
            navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                 initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                 target:self
                                                 action:@selector(done)];
        }
    }
    requiredInsets = scrollView.contentInset;
    currentScrollView = scrollView;
    [scrollView addObserver:self forKeyPath:@"contentInset" options:0 context:nil];
}

- (void) detachScrollView
{
    if (currentScrollView == nil) {
        return;
    }
    // remove the Done button from the navigation bar
    if (navigationItem != nil) {
        navigationItem.rightBarButtonItem = nil;
        navigationItem = nil;
    }
    currentScrollView.pagingEnabled = oldPagingEnabled;
    currentScrollView.scrollEnabled = YES;
    oldPagingEnabled = NO;
    // remove the tap gesture recognizer
    [currentScrollView removeGestureRecognizer:gesture];

    [currentScrollView removeObserver:self forKeyPath:@"contentInset"];
    requiredInsets = originalInsets;
    currentScrollView.contentInset = originalInsets;
    currentScrollView = nil;
}

- (UIScrollView *) findEnclosingScrollView:(UIView *)view
{
    do {
        view = view.superview;
    } while (view != nil && ![view isKindOfClass:[UIScrollView class]]);
    // BUG-FIX V6.6
    if ([view.superview isKindOfClass:[UITableView class]]) {
        // UITableView has an internal hidden UIScrollView before iOS 11
        // return the UITableView itself instead
        view = view.superview;
    }
    // END BUG-FIX
    // BUG-FIX 6.9: assume each tableview has a UITableViewController which does all the keyboard handling
    // itself already
    if ([view isKindOfClass:[UITableView class]]) {
        // BUG-FIX 6.11: not all UITableViews have UITableViewControllers. Check it explicitly
        UITableView *tableView = (UITableView *) view;
        if ([tableView.delegate isKindOfClass:[UITableViewController class]]) {
            return nil;
        }
    }
    return (UIScrollView *)view;
}

#pragma mark - Notifications

- (void) fieldSelected:(NSNotification *)notification
{
    UITextField *field = notification.object;
    [self setField:field];
}

- (void) fieldDeselected:(NSNotification *)aNotification
{
    [self setField:nil];
}

- (void) keyboardWillShow:(NSNotification *)aNotification
{
    if (selectedField == nil) {
        return;
    }
    if (currentScrollView == nil) {
        UIScrollView *view = [self findEnclosingScrollView:selectedField];
        [self attachScrollView:view];
    }
    [self keyboardWillChangeFrame:aNotification];
}

- (void) keyboardWillHide:(NSNotification *)aNotification
{
    // BUG-FIX V6.6: always detach, even when field is already deselected
    // if (selectedField == nil) {
    if (currentScrollView == nil) {
        return;
    }
    [self keyboardWillChangeFrame:aNotification];
    [self detachScrollView];
}

- (void) keyboardWillChangeFrame:(NSNotification *)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGRect endRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    UIViewAnimationCurve curve = [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    
    // If the text field is hidden by the keyboard, scroll it so it's visible
    CGFloat pos = [currentScrollView.superview convertRect:endRect fromView:nil].origin.y;
    CGFloat bottomInset = CGRectGetMaxY(currentScrollView.frame) - pos;
    if (@available(iOS 11, *)) {
        if (currentScrollView.contentInsetAdjustmentBehavior != UIScrollViewContentInsetAdjustmentNever) {
            bottomInset -= currentScrollView.safeAreaInsets.bottom;
        }
    }
    UIEdgeInsets insets = originalInsets;
    insets.bottom = MAX(originalInsets.bottom, bottomInset);
    
    CGRect rect = [currentScrollView convertRect:selectedField.bounds fromView:selectedField];
    // set some margin
    rect = CGRectInset(rect, 0, -10);
    
    // scroll the view with the same animation as the keyboard
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:duration];
    [UIView setAnimationCurve:curve];
    
    requiredInsets = insets;
    [currentScrollView setContentInset:insets];
    [currentScrollView scrollRectToVisible:rect animated:NO];
    
    [UIView commitAnimations];
}

#pragma mark - Object Life Cycle

- (instancetype) init
{
    if (!(self = [super init])) {
        return nil;
    }
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(keyboardWillShow:)
                   name:UIKeyboardWillShowNotification object:nil];
    
    [center addObserver:self
               selector:@selector(keyboardWillHide:)
                   name:UIKeyboardWillHideNotification object:nil];

    [center addObserver:self
               selector:@selector(fieldDeselected:)
                   name:UITextFieldTextDidEndEditingNotification object:nil];
    
    [center addObserver:self
               selector:@selector(fieldSelected:)
                   name:UITextFieldTextDidBeginEditingNotification object:nil];
    
    gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(done)];
    
    return self;
}

static KeyboardScroller *theScroller;
+ (void) start
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        theScroller = [[KeyboardScroller alloc] init];
    });
}

@end
