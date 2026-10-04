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
    function newestRows(unreadOnly) {
        if (unreadOnly && unreadCount === 0) return [];
        for (const days of [7, 90, 365, null]) {
            const filters = [{deletedStatus:false}, {junkMailStatus:false}];
            if (unreadOnly) filters.push({readStatus:false});
            if (days !== null) filters.push({dateReceived:{_greaterThan:new Date(Date.now()-days*86400000)}});
            const pool = box.messages.whose({_and:filters});
            const ids = pool.id(), dates = pool.dateReceived();
            if (ids.length !== dates.length) throw new Error('Inbox changed while reading. Will retry.');
            const rows = ids.map((id,i)=>({id:id, receivedAt:dates[i].getTime()/1000}))
                .sort((a,b)=>b.receivedAt-a.receivedAt || b.id-a.id).slice(0,10);
            if (rows.length === 10 || days === null) return rows;
        }
    }
    const headers = {};
    function expand(row) {
        if (headers[row.id]) return headers[row.id];
        const msg = box.messages.byId(row.id);
        return headers[row.id] = {id:row.id, receivedAt:row.receivedAt, sender:msg.sender(),
            subject:msg.subject(), messageID:msg.messageId() || '', isRead:msg.readStatus(), inboxID:inboxID};
    }
    const unreadMessages = newestRows(true).map(expand);
    const recentMessages = newestRows(false).map(expand);
    return JSON.stringify({status:'ready', detail:'', inboxes:[{id:inboxID, name:label(account),
        unreadCount:unreadCount, unreadMessages:unreadMessages, recentMessages:recentMessages}]});
}
