//
//  PharmacyActionableNotifications.m
//  Atlantic Pharmacy
//
//  Created by Roman Antonov on 13/9/20.
//

#import "PharmacyActionableNotifications.h"
#import <WebKit/WKWebView.h>

@implementation PharmacyActionableNotifications

- (void)updateHistoryAction:(NSDictionary *)userInfo
                AppDelegate:(AppDelegate *) appDelegate {
    if ([[userInfo objectForKey:@"action"] isEqualToString:@"snooze"]
        || [[userInfo objectForKey:@"action"] isEqualToString:@"take"]
        || [[userInfo objectForKey:@"action"] isEqualToString:@"skip"]) {
        
        // Get data from localStorage of wkwebview
        [(WKWebView*) appDelegate.viewController.webView
            evaluateJavaScript:@"JSON.stringify({device_token_key: localStorage.device_token_key, \
                device_token: localStorage.device_token, \
                API_URL: localStorage.API_URL, \
                API_KEY: localStorage.API_KEY})"
            completionHandler:^(NSString* result, NSError *error) {
            
            if (error == nil) {
                if (result != nil) {
                    NSError *jsonError;
                    NSData *objectData = [result dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
                                                          options:NSJSONReadingMutableContainers
                                                            error:&jsonError];
                    
                    NSString *url = [json objectForKey:@"API_URL"];
                    url = [url stringByAppendingString:@"api/update-history-action/"];
                    url = [url stringByAppendingString:[json objectForKey:@"API_KEY"]];
                    
                    NSString *params = [NSString stringWithFormat:@"device_token_key=%@&device_token=%@&action=%@&recurring_id=%@&history_id=%@&device_type=%@",
                                        [json objectForKey:@"device_token_key"],
                                        [json objectForKey:@"device_token"],
                                        [userInfo objectForKey:@"action"],
                                        [userInfo objectForKey:@"recurring_id"],
                                        [userInfo objectForKey:@"history_id"],
                                        @"apns"];
                    NSLog(@"POST PARAMS -> %@", params);
                    NSLog(@"POST RESULT -> %@", [self sendPOST:url withParams:params]);
                }
            }
            
        }];
    }
}

- (NSString *) sendPOST:(NSString *)endpoint withParams:(NSString *)params {
    NSData *postData = [params dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu",[postData length]];


    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"POST"];
    [request setURL:[NSURL URLWithString:endpoint]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];

    NSError *error = nil;
    NSHTTPURLResponse *responseCode = nil;

    NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];

    if([responseCode statusCode] != 200){
        NSLog(@"Error getting %@, HTTP status code %li", endpoint, (long)[responseCode statusCode]);
        return nil;
    }

    return [[NSString alloc] initWithData:oResponseData encoding:NSUTF8StringEncoding];
}

@end
