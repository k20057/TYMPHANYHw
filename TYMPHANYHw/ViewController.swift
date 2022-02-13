//
//  ViewController.swift
//  TYMPHANYHw
//
//  Created by  明智 on 2022/2/12.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var connectionState: UILabel!
    
    var CBcentralManager : CBCentralManager!
    
    var targetService: CBService?
    var selectPeripheral: CBPeripheral?
    var targetCharacteristic: CBCharacteristic?
    
    var peripheralSets = Set<CBPeripheral>()
    var peripherals = Array<TYMPeripherial>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let dispatchQueue = DispatchQueue.main
        
        CBcentralManager = CBCentralManager(delegate: self, queue: dispatchQueue)
        
    }


    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
    }
    
    @IBAction func Scan(_ sender: Any) {
        if(navigationItem.rightBarButtonItem?.title == "Scan") {
            peripherals.removeAll()
            selectPeripheral = nil
            peripheralSets.removeAll()
            CBcentralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            tableView.reloadData()
            navigationItem.rightBarButtonItem?.title = "Stop"
        }else {
            CBcentralManager.stopScan()
            navigationItem.rightBarButtonItem?.title = "Scan"
        }
        
    }
    
    
    //connect
    func isConnected(peripheral: CBPeripheral) -> Bool {
            let state = peripheral.state
            
            switch state {
            case .connected:
                return true
            default:
                return false
            }

    }
    
    func connectPeripheral(peripheral : CBPeripheral) {
        CBcentralManager.stopScan()
        
        if(peripheral.state == .connected || peripheral.state == .connecting) {
            return
        }
        
        selectPeripheral = peripheral
        selectPeripheral!.delegate = self
        
        CBcentralManager.connect(peripheral)
    }
    
    
    //Disconnect
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {

        DispatchQueue.main.async {
            self.connectionState.text = "Disconnected"
        }
    }
    
    func disconnect(peripheral : CBPeripheral?) {
        if peripheral == nil {
            return
        }

        CBcentralManager.cancelPeripheralConnection(peripheral!)
    }
    
    //Peripheral connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        print("didConnect", peripheral.name ?? "unknown")
        
        //centralGR.isStatusConnected = true
        
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        
        print("connected mtu", String(mtu))
        
        //centralGR.flashTaskManager.MTU = mtu
        
        peripheral.discoverServices([BleService.UUID_SERVICE])
    }
    
}

extension ViewController {

    //Peripheral discovered
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
   
        print("\(peripheral), \(RSSI)")
        
        // use a set to check
        if peripheralSets.contains(peripheral) {
            return
        }
        
        var advDeviceName: String!
        
        if advertisementData["kCBAdvDataLocalName"] as? String == nil {
            advDeviceName = "unknown"
            return
        } else {
            advDeviceName = (advertisementData["kCBAdvDataLocalName"] as! String)
        }
        
        let logMsg = String("[\(advDeviceName)][\(peripheral.identifier)]")
        print("logMsg",logMsg)
        
        peripheralSets.insert(peripheral)
        
        let wrapPeripherial = TYMPeripherial(id: peripheral.identifier.uuidString, peripheral: peripheral, Name: advDeviceName)
 
        peripherals.append(wrapPeripherial)
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Service disconvered
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        guard let services = peripheral.services else { return }

        if services.isEmpty || services.count < 0 {
            return
        }
            
        targetService = services[0]
        
        // only one service is needed
        peripheral.discoverCharacteristics([BleCharacteristics.UUID_CHARACTERISTIC], for: targetService!)
    }
    
    //Charcs discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for charc in characteristics {
            
            if charc.uuid.isEqual(BleCharacteristics.UUID_CHARACTERISTIC) {
                
                targetCharacteristic = charc
                
                peripheral.setNotifyValue(true, for: targetCharacteristic!)
            }

        }
  
        if(targetCharacteristic != nil ) {
            DispatchQueue.main.async {
                self.connectionState.text = "Connected"
            }
        } else {
            print("Target Charc. Not Found")
        }
    }
    
    //Charc Value Updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        guard error == nil else {
            print("error",error!)
            return
        }
 
        guard let dataReceived = characteristic.value else {

            return
        }
        
        print("receiveData",dataReceived)
        
    }
}


extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell  = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    
        cell.textLabel?.text = peripherals[indexPath.row].Name
        //cell.configureButton(with: "Connect")
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("test selected")
        self.selectPeripheral = peripherals[indexPath.row].peripheral
        
        if let selectPeripheral = selectPeripheral {
            if isConnected(peripheral: selectPeripheral) {
                disconnect(peripheral: selectPeripheral)
            } else {
                connectPeripheral(peripheral: selectPeripheral)
            }
        }
    }
}



struct TYMPeripherial : Identifiable{
    public var id: String
    public var peripheral: CBPeripheral
    public var Name: String
    //public var Rssi: Int

}
