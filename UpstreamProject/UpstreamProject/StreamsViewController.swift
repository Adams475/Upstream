//
//  StreamsViewController.swift
//  UpstreamProject
//
//  Created by Simon Mason on 12/3/23.
//

import UIKit


class StreamsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {


    
    var testList = ["1", "2", "3"]
    @IBOutlet weak var dropdownButton: UIButton!
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cellId")
        tableView.isHidden = true
        // Do any additional setup after loading the view.

    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "cellId", for: indexPath)
        cell.textLabel?.text = testList[indexPath.row]
        cell.backgroundColor = UIColor.blue
        print(testList[indexPath.row])
        return cell
    }

    @IBAction func onDropdownClick(_ sender: Any) {
        print("unhiding")
        tableView.isHidden = !tableView.isHidden
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SVC" {
            if let destinationVC = segue.destination as? RequestingStreamViewController {
                let index = tableView.indexPathForSelectedRow?.item
                destinationVC.streamId = testList[index ?? 0]
            }
        }
    }
    
}


