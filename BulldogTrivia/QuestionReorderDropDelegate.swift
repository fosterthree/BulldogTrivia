//  QuestionReorderDropDelegate.swift
//  BulldogTrivia

//  Handles the drag-and-drop logic for questions.

//  Created by Asa Foster on 1/20/26.

import SwiftUI

struct QuestionReorderDropDelegate: DropDelegate {
let targetID: UUID
@Binding var questions: [Question]
@Binding var draggingID: UUID?

func dropEntered(info: DropInfo) {
    guard let draggingID,
          draggingID != targetID,
          let from = questions.firstIndex(where: { $0.id == draggingID }),
          let to = questions.firstIndex(where: { $0.id == targetID })
    else { return }

    withAnimation(.snappy) {
        questions.move(
            fromOffsets: IndexSet(integer: from),
            toOffset: to > from ? to + 1 : to
        )
    }
}

func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
}

func performDrop(info: DropInfo) -> Bool {
    draggingID = nil
    return true
}

func validateDrop(info: DropInfo) -> Bool { true }
}
