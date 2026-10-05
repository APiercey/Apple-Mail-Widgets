function run(args) {
    const mail = Application('com.apple.mail');
    if (!mail.running()) return JSON.stringify({status:'mailClosed', detail:'Open Apple Mail to resume updates.'});
    const accounts = mail.accounts().filter(a => a.enabled());
    function label(account) {
        const addresses = account.emailAddresses();
        return account.name() + (addresses.length ? ' · ' + addresses[0] : '');
    }
    // Discovery must not enumerate messages: a syncing inbox can take far longer.
    if (args[0] === 'catalog') {
        return JSON.stringify({status:'catalog', detail:'', inboxes:accounts.map(a => ({
            id:a.id(), name:label(a), unreadCount:0, unreadMessages:[], recentMessages:[]
        }))});
    }
    const inboxID = args[0];
    const boxes = mail.inbox.mailboxes();
    const account = accounts.find(a => a.id() === inboxID);
    const box = boxes.find(b => b.account.id() === inboxID);
    if (!account || !box) throw new Error('This inbox is not available from Apple Mail yet.');
    // Use Mail's inbox count; counting a filtered collection can scan years of mail.
    const unreadCount = box.unreadCount();
    // Mail's `whose` predicates scan the mailbox for each requested property.
    // Bulk primitive columns are much faster, and do not fetch bodies or attachments.
    const ids = box.messages.id();
    const dates = box.messages.dateReceived();
    const read = box.messages.readStatus();
    const deleted = box.messages.deletedStatus();
    const junk = box.messages.junkMailStatus();
    const finalIDs = box.messages.id();
    if ([dates, read, deleted, junk, finalIDs].some(values => values.length !== ids.length) ||
        ids.some((id, index) => id !== finalIDs[index])) {
        throw new Error('Inbox changed while reading. Will retry.');
    }
    const rows = ids.map((id, index) => ({id:id, receivedAt:dates[index].getTime()/1000,
        isRead:read[index], deleted:deleted[index], junk:junk[index]}))
        .filter(row => !row.deleted && !row.junk)
        .sort((a,b) => b.receivedAt-a.receivedAt || b.id-a.id);
    const headers = {};
    function expand(row) {
        if (headers[row.id]) return headers[row.id];
        const msg = box.messages.byId(row.id);
        return headers[row.id] = {id:row.id, receivedAt:row.receivedAt, sender:msg.sender(),
            subject:msg.subject(), messageID:msg.messageId() || '', isRead:msg.readStatus(), inboxID:inboxID};
    }
    const unreadMessages = rows.filter(row => !row.isRead).slice(0,10).map(expand);
    const recentMessages = rows.slice(0,10).map(expand);
    return JSON.stringify({status:'ready', detail:'', inboxes:[{id:inboxID, name:label(account),
        unreadCount:unreadCount, unreadMessages:unreadMessages, recentMessages:recentMessages}]});
}
