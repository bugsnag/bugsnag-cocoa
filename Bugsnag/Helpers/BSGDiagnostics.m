//
//  BGSDiagnostics.mm
//  Bugsnag
//
//  Created by Robert Bartoszewski on 04/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSGDiagnostics.h"

#import <stdatomic.h>

struct bsg_diagnostic_message_list_item {
    struct bsg_diagnostic_message_list_item *next;
    struct bsg_diagnostic_message_list_item *previous;
    const char *message; // MUST be null terminated
};

static _Atomic(struct bsg_diagnostic_message_list_item *) g_diagnostic_messages_head;
static _Atomic(struct bsg_diagnostic_message_list_item *) g_diagnostic_messages_tail;
static atomic_bool g_writing_crash_report;

void _awaitAtomicDiagnosticMessagesLockIfNeeded(void) {
    while (atomic_load(&g_writing_crash_report)) { continue; }
}

void logDiagnosticMessage(const char *message) {
    _awaitAtomicDiagnosticMessagesLockIfNeeded();
    unsigned long length = strlen(message);
    struct bsg_diagnostic_message_list_item *head = atomic_load(&g_diagnostic_messages_head);
    struct bsg_diagnostic_message_list_item *tail = atomic_load(&g_diagnostic_messages_tail);
    struct bsg_diagnostic_message_list_item *newItem = calloc(1, sizeof(struct bsg_diagnostic_message_list_item) + length + 1);
    if (!newItem) {
        return;
    }
    newItem->message = message;
    
    if (head == NULL) {
        _awaitAtomicDiagnosticMessagesLockIfNeeded();
        atomic_store(&g_diagnostic_messages_head, newItem);
    }
    if (tail) {
        _awaitAtomicDiagnosticMessagesLockIfNeeded();
        tail->next = newItem;
    }
    _awaitAtomicDiagnosticMessagesLockIfNeeded();
    newItem->previous = tail;
    atomic_store(&g_diagnostic_messages_tail, newItem);
}

void BugsnagDiagnosticsWriteCrashReport(const BSG_KSCrashReportWriter * _Nonnull writer,
                                        bool __unused requiresAsyncSafety) {
    atomic_store(&g_writing_crash_report, true);
    
    writer->beginArray(writer, "diagnostics");
    
    struct bsg_diagnostic_message_list_item *item = atomic_load(&g_diagnostic_messages_head);
    while (item) {
        writer->addStringElement(writer, NULL, item->message);
        item = item->next;
    }
    
    writer->endContainer(writer);
    
    atomic_store(&g_writing_crash_report, false);
}
