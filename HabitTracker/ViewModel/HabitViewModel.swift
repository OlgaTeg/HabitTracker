//
//  HabitViewModel.swift
//  HabitTracker
//
//  Created by Olga Tegza on 01.03.2023.
//

import SwiftUI
import CoreData
import UserNotifications

class HabitViewModel: ObservableObject {
    //MARK: New habit properties
    @Published var addNewHabit: Bool = false
    
    @Published var title: String = ""
    @Published var habitColor: String = "Card-1"
    @Published var weekDays: [String] = []
    @Published var isReminderOn: Bool = false
    @Published var reminderText: String = ""
    @Published var reminderDate: Date = Date()
    
    @Published var showTimePicker: Bool = false
    
    @Published var editHabit: Habit?
    
    @Published var notificationAccess: Bool = false
    
    init() {
        requestNotificationAccess()
    }
    
    func requestNotificationAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { status, _ in
            DispatchQueue.main.async {
                self.notificationAccess = status
            }
        }
    }
    
    func addHabit(context: NSManagedObjectContext)async->Bool {
        var habit: Habit!
        if let editHabit = editHabit {
            habit = editHabit
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: editHabit.notificationsIDs ?? [])
        } else {
            habit = Habit(context: context)
        }
        habit.title = title
        habit.color = habitColor
        habit.weekDays = weekDays
        habit.isReminderOn = isReminderOn
        habit.remainderText = reminderText
        habit.notificationDate = reminderDate
        habit.notificationsIDs = []
        
        if isReminderOn {
            if let ids = try? await scheduleNotification() {
                habit.notificationsIDs = ids
                if let _ = try? context.save() {
                    return true
                }
            }
        } else {
            if let _ = try? context.save() {
                return true
            }
        }
        return false
    }
    
    func scheduleNotification()async throws-> [String] {
        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder"
        content.subtitle = reminderText
        content.sound = UNNotificationSound.default
        
        var notificationIDs: [String] = []
        let calendar = Calendar.current
        let weekdaySymbols: [String] = calendar.weekdaySymbols
        
        for weekDay in weekDays {
            let id = UUID().uuidString
            let hour = calendar.component(.hour, from: reminderDate)
            let min = calendar.component(.minute, from: reminderDate)
            let day = weekdaySymbols.firstIndex { currentDay in
                return currentDay == weekDay
            } ?? -1
            if day != 1 {
                var components = DateComponents()
                components.hour = hour
                components.minute = min
                components.weekday = day + 1
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                
                try await UNUserNotificationCenter.current().add(request)
                
                notificationIDs.append(id)
            }
        }
        
        return notificationIDs
    }
    
    func resetData() {
        title = ""
        habitColor = "Card-1"
        weekDays = []
        isReminderOn = false
        reminderDate = Date()
        reminderText = ""
        editHabit = nil
    }
    
    func deleteHabit(context: NSManagedObjectContext)->Bool {
        if let editHabit = editHabit {
            if editHabit.isReminderOn {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: editHabit.notificationsIDs ?? [])
            }
            context.delete(editHabit)
            if let _ = try? context.save() {
                return true
            }
        }
        return false
    }
    
    func restoreEditData() {
        if let editHabit = editHabit {
            title = editHabit.title ?? ""
            habitColor = editHabit.color ?? "Card-1"
            weekDays = editHabit.weekDays ?? []
            isReminderOn = editHabit.isReminderOn
            reminderDate = editHabit.notificationDate ?? Date()
            reminderText = editHabit.remainderText ?? ""
        }
    }
    
    func doneStatus()-> Bool {
        let reminderStatus = isReminderOn ? reminderText == "" : false
        
        if title == "" || weekDays.isEmpty || reminderStatus {
            return false
        }
        return true
    }
}
