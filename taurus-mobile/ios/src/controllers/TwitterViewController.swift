/*
* Numenta Platform for Intelligent Computing (NuPIC)
* Copyright (C) 2015, Numenta, Inc.  Unless you have purchased from
* Numenta, Inc. a separate commercial license for this software code, the
* following terms and conditions apply:
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License version 3 as
* published by the Free Software Foundation.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
* See the GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see http://www.gnu.org/licenses.
*
* http://numenta.org/licenses/
*
*/


import UIKit

class TwitterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate  {
    
    @IBOutlet var timeSlider: TimeSliderView?
    @IBOutlet weak var instanceTable: UITableView!
    @IBOutlet weak var anomalyChartView : AnomalyChartView!
    @IBOutlet weak var metricChartView : LineChartView!
    
    @IBOutlet weak var ticker : UILabel!
    @IBOutlet weak var name : UILabel!
    @IBOutlet weak var date : UILabel!
    @IBOutlet weak var menuButton:UIBarButtonItem!
    @IBOutlet weak var condensedToggle: UISwitch?
    
    var showCondensed = false
    
    // Serial queue for loading chart data
    let loadQueue = dispatch_queue_create("com.numenta.TwitterController", nil)
    
    var  metricChartData : MetricAnomalyChartData?
    
    //
    var _aggregation: AggregationType = TaurusApplication.getAggregation()
       
   // var tableData = [InstanceAnomalyChartData]()
    
    
    var chartData: InstanceAnomalyChartData? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
    @IBAction func toggleCondensed(){
        self.showCondensed = (condensedToggle?.on)!
        self.instanceTable.reloadData()
        
        if (self.showCondensed){
            self.instanceTable.separatorColor =  UIColor.blackColor()
        } else{
            self.instanceTable.separatorColor = UIColor.lightGrayColor()
        }
    }
    
    /** bind data to view
    */
    func configureView() {
        if (chartData == nil){
            return
        }
        
        if ( chartData?.getEndDate() != nil){
            timeSlider?.endDate = (chartData?.getEndDate()!)!
        }
        anomalyChartView?.setData (chartData!.getData())
        
        ticker?.text = chartData?.ticker
        name?.text = chartData?.name
        
        if (metricChartData != nil && metricChartData?.rawData != nil ){
            metricChartView?.data  = metricChartData!.rawData!
            metricChartView?.anomalies = metricChartData!.data!
            metricChartView?.updateData()
        }
        

        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
       
       
        timeSlider?.showBottom = false
        timeSlider?.transparentBackground = true
        // on iOS 8+ need to make sure table background is clear
        
        instanceTable.backgroundColor = UIColor.clearColor()
          self.instanceTable.estimatedRowHeight = 80.0
        self.instanceTable.rowHeight = UITableViewAutomaticDimension
        
        if self.revealViewController() != nil {
            let menuIcon = UIImage(named: "menu")
            let b2 = UIBarButtonItem (image: menuIcon,  style: UIBarButtonItemStyle.Plain, target: self.revealViewController(), action: "rightRevealToggle:")
            self.menuButton = b2
            
            self.navigationItem.rightBarButtonItems = [menuButton!]
            
            self.view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        }
        
        condensedToggle?.on = false
        self.instanceTable.separatorColor = UIColor.lightGrayColor()
        configureView()
        
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            self.loadTwitterData()
        }
        
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /** Datasource delegate
    - returns : number of sections in table
    */
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return twitterIndex.count

    }
    
    /** header title
    */
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String?{
        let ts = twitterIndex [section]
        let date = DataUtils.dateFromTimestamp(ts)
        
       
        let formatter = NSDateFormatter()
        formatter.dateFormat = "h:mma"
        
        let s = formatter.stringFromDate ( date )
        return s
    }
    
    /** Datasource delegate to return number of rows in a cell.
    */
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int{
        let tsIndex = twitterIndex[section]
        let items : [Tweet]? = twittermap[tsIndex]
        
        if ( items != nil){
            return items!.count
        }
        
        
        return 0
    }
    
    
    /** bind data to cell and return the cell
    */
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell!{
        
        let cell:TwitterCell? = self.instanceTable.dequeueReusableCellWithIdentifier("TwitterCell") as! TwitterCell?
        
        let section = indexPath.section
        let tsIndex = twitterIndex[section]
        let items : [Tweet]? = twittermap[tsIndex]
        let tweet = items![ indexPath.item]
        
        if (showCondensed){
            let attrs = [NSFontAttributeName : UIFont.boldSystemFontOfSize(14.0)]
            var attrStr = NSMutableAttributedString(string: tweet.cannonicalText, attributes:attrs)
            if (tweet.hasLinks){
                let bodyAttrs = [NSFontAttributeName : UIFont.systemFontOfSize(14.0)]
                var tweetText = NSMutableAttributedString(string: " links", attributes:bodyAttrs)
                attrStr.appendAttributedString(tweetText)
            
            }
            cell?.label?.attributedText = attrStr
        }else{
        
            let attrs = [NSFontAttributeName : UIFont.boldSystemFontOfSize(14.0)]
            var attrStr = NSMutableAttributedString(string:"@" + tweet.userName, attributes:attrs)
            let bodyAttrs = [NSFontAttributeName : UIFont.systemFontOfSize(14.0)]
               var tweetText = NSMutableAttributedString(string: "\r\n" + tweet.text, attributes:bodyAttrs)
            
            attrStr.appendAttributedString(tweetText)
            
            
      
            cell?.label?.attributedText = attrStr
        }
        return cell
    }
    
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath)
    {
        
    }
    
    
    var twittermap = [ Int64 : [Tweet]]()
    var twitterIndex = [Int64]()
    /** load twitter data
        fixme - do the more optimal load
    */
    func loadTwitterData(){
        let client = TaurusApplication.connectToTaurus()
        let metric = metricChartData?.metric
        
        let start = metricChartData!.getStartTimestamp()
        let endTime = metricChartData!.getEndDate()// + DataUtils.MILLIS_PER_HOUR;
        
        client?.getTweets( (metric?.getName())!, from: start, to: endTime! ){ (tweet: Tweet?)in
            if (tweet != nil){
                
                let aggregationTime : Int64 = tweet!.aggregated
                var items :[Tweet]? = self.twittermap[ aggregationTime]
                
                if (items == nil){
                    self.twittermap[aggregationTime] = [tweet!]
                }else{
                    items!.append(tweet!)
                    self.twittermap[aggregationTime] = items
                }
            }
           
            return nil
        }
        
        // Update the table to the new data
        dispatch_async(dispatch_get_main_queue()) {
           
            self.twitterIndex = Array(self.twittermap.keys)
            
            self.twitterIndex.sortInPlace {
                return $0 >  $1
            }
            
            self.instanceTable?.reloadData()
        }

    }
    
    
    
    
    
}

