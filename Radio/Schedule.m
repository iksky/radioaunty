//
//  Schedule.m
//  Radio
//
//  Created by Duncan Robertson on 18/12/2008.
//  Copyright 2008 Whomwah. All rights reserved.
//

#import "Broadcast.h"
#import "Service.h"
#import "Schedule.h"
#import "NSString-Utilities.h"

#define API_URL @"http://www.bbc.co.uk/%@programmes/schedules%@.xml";

@implementation Schedule

@synthesize lastUpdated, service, displayTitle, displaySynopsis, broadcasts;

-(id)init
{
  [self dealloc];
  @throw [NSException exceptionWithName:@"DSRBadInitCall" 
                                 reason:@"Initialize BBCSchedule with initUsingService:outlet:" 
                               userInfo:nil];
  return nil;
}

- (id)initUsingService:(NSString *)sv outlet:(NSString *)ol;
{
  if (![super init])
    return nil;
  
  outletKey = ol;
  serviceKey = sv;
  [self fetch:[self buildUrl]];
  
  return self;
}

- (NSURL *)buildUrl
{
  NSString *api = API_URL;
  NSString *serviceStr = @"", *outletStr = @"", *urlStr;

  if (outletKey)
    outletStr = [NSString stringWithFormat:@"/%@", outletKey];
  
  if (serviceKey)
    serviceStr = [NSString stringWithFormat:@"%@/", serviceKey];
  
  urlStr = [NSString stringWithFormat:api, serviceStr, outletStr];
  NSLog(@"URL: %@", urlStr);
  return [NSURL URLWithString:urlStr];
}

- (void)fetch:(NSURL *)url
{
  NSURLRequest *theRequest = [NSURLRequest requestWithURL:url
                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                          timeoutInterval:60.0];

  NSURLConnection * theConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
  if (theConnection) {
    receivedData = [[NSMutableData data] retain];
  } else {
    [theConnection release];
    NSLog(@"download failed!");
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
  [receivedData setLength:0];
  expectedLength = [response expectedContentLength];
  [self setDisplayTitle:@"Loading Schedule..."];
  NSLog(@"Yay, we got a response");
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [receivedData appendData:data];
  float percentComplete = ([receivedData length]/expectedLength)*100.0;
  NSLog(@"data is being fetched: %1.0f%%", percentComplete);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
  [connection release];
  [receivedData release];
  
  NSLog(@"Connection failed! Error - %@ %@",
        [error localizedDescription],
        [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  NSLog(@"Finished! Received %d bytes of data", [receivedData length]);
  NSError *error;
  
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:receivedData options:0 error:&error];
  
  if (error != nil) {
    NSLog(@"An Error occured reading the schedule: %@", error);
  }
  
  xmlDocument = doc;
  [self setServiceData];
  [self setBroadcastData];
  [self setDisplayTitle:[service displayTitle]];
  [self setLastUpdated:[NSDate date]];
  
  [doc release];
  [connection release];
  [receivedData release];
}

- (void)setServiceData
{
  NSError *error;
  NSArray *data = [xmlDocument nodesForXPath:@".//schedule/service[@type=\"radio\"]" error:&error];
  
  if (error != nil)
    NSLog(@"An Error occured: %@", error);
  
  Service *s = [[Service alloc] initUsingServiceXML:data];
  [self setService:s];
  [s release];
}

#pragma mark broadcasts

- (void)setBroadcastData
{
  NSError *error;
  NSArray *data = [xmlDocument nodesForXPath:@".//schedule/*/broadcasts/broadcast" error:&error];
  
  if (error != nil)
    NSLog(@"An Error occured: %@", error);
  
  NSMutableArray *temp = [NSMutableArray array];
  
  for (NSXMLNode *broadcast in data) {    
    Broadcast *b = [[Broadcast alloc] initUsingBroadcastXML:broadcast];
    [temp addObject:b];
    [b release];
  }
  
  [self setBroadcasts:temp];
}

- (Broadcast *)currBroadcast
{
  NSDate *now = [NSDate date];
  
  for (Broadcast *broadcast in broadcasts) {
    if (([now compare:[broadcast bStart]] == NSOrderedDescending) && 
        ([now compare:[broadcast bEnd]] == NSOrderedAscending)) {
      return broadcast;
    }
  }
  return nil;
}

- (Broadcast *)nextBroadcast
{
  int index = [broadcasts indexOfObject:[self currBroadcast]];
  
  if (index != NSNotFound && index+1 <= [broadcasts count]) {
    index++;
  }
  
  return [broadcasts objectAtIndex:index];
}

- (Broadcast *)prevBroadcast
{
  int index = [broadcasts indexOfObject:[self currBroadcast]];
  
  if (index != NSNotFound && index-1 >= 0) {
    index++;
  }
  
  return [broadcasts objectAtIndex:index];
}

- (NSString *)nowOnInFull
{
  return [NSString stringWithFormat:@"%@ - %@", 
                              [[self service] displayTitle],
                              [[self currBroadcast] displayTitle]];
}

- (NSString *)broadcastTitleWithServiceForIndex:(NSUInteger)index
{
  ;
  return [NSString stringWithFormat:@"%@ - %@", 
          [[self service] displayTitle],
          [[[self broadcasts] objectAtIndex:index] displayTitle]];
}

@end
