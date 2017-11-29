//
//  KeyboardScroller.m
//  Flyskyhy
//
//  Created by René Dekker on 2017-11-19.
//  Copyright © 2017 Renevision. All rights reserved.
//

#import "KeyboardScroller.h"
#import <UIKit/UIKit.h>

@implementation KeyboardScroller {
    UITextField *selectedField;
    UIScrollView *currentScrollView;
    bool oldPagingEnabled;
    UIEdgeInsets originalInsets;
    UIEdgeInsets requiredInsets;
    UINavigationItem *navigationItem;
    UIToolbar *numberToolbar;
    UIGestureRecognizer *gesture;
}

- (void) done
{
    if (currentScrollView != nil) {
        [currentScrollView endEditing:YES];
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                        context:(void *)context
{
    UIScrollView *scrollView = (UIScrollView *) object;
    UIEdgeInsets insets = scrollView.contentInset;
    if (!UIEdgeInsetsEqualToEdgeInsets(requiredInsets, insets)) {
        currentScrollView.contentInset = requiredInsets;
    }
}

- (UIToolbar *) createNumberToolbar
{
    numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    numberToolbar.barStyle = UIBarStyleDefault;
    numberToolbar.items = @[
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)]
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
    if (selectedField != nil && numberToolbar != nil) {
        selectedField.inputAccessoryView = nil;
        numberToolbar = nil;
    }
    selectedField = nil;
    if (field != nil) {
        UIScrollView *view = [self findEnclosingScrollView:field];
        if (view == nil) {
            // the new field is not enclosed in a scroll view
            [self detachScrollView];
            return;
        }
        selectedField = field;
        [self attachScrollView:view];
        // if it is not a normal keyboard, and we have not added a Done button to the navigation bar
        // then add a toolbar with Done button to the keyboard
        if (navigationItem == nil &&
            selectedField.keyboardType != UIKeyboardTypeDefault &&
            selectedField.inputAccessoryView == nil)
        {
            selectedField.inputAccessoryView = [self createNumberToolbar];
        }
    }
}

- (void) attachScrollView:(UIScrollView *)scrollView
{
    if (scrollView == currentScrollView) {
        return;
    }
    [self detachScrollView];
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
    if (selectedField == nil) {
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
    rect.origin.y -= 5;
    rect.size.height += 20;
    
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
