function run() {
    const mail = Application('com.apple.mail');
    if (!mail.running()) return JSON.stringify({status:'mailClosed', detail:'Open Apple Mail to resume updates.'});
    function newestRows(pool) {
        const ids = pool.id(), dates = pool.dateReceived();
        return {count:ids.length, rows:ids.map((id,i)=>({id:id, receivedAt:dates[i].getTime()/1000}))
            .sort((a,b)=>b.receivedAt-a.receivedAt || b.id-a.id).slice(0,10)};
    }
    const inboxes = mail.inbox.mailboxes().map(box => {
        const account = box.account;
        const inboxID = account.id();
        const addresses = account.emailAddresses();
        const label = account.name() + (addresses.length ? ' · ' + addresses[0] : '');
        const unread = newestRows(box.messages.whose({_and:[
            {readStatus:false}, {deletedStatus:false}, {junkMailStatus:false}
        ]}));
        const recent = newestRows(box.messages.whose({_and:[{deletedStatus:false}, {junkMailStatus:false}]}));
        const headers = {};
        function expand(row) {
            if (headers[row.id]) return headers[row.id];
            const msg = box.messages.byId(row.id);
            return headers[row.id] = {id:row.id, receivedAt:row.receivedAt, sender:msg.sender(),
                subject:msg.subject(), messageID:msg.messageId() || '', isRead:msg.readStatus(), inboxID:inboxID};
        }
        return {id:inboxID, name:label, unreadCount:unread.count,
            unreadMessages:unread.rows.map(expand), recentMessages:recent.rows.map(expand)};
    });
    const combined = [].concat.apply([],inboxes.map(b=>b.unreadMessages))
        .sort((a,b)=>b.receivedAt-a.receivedAt || b.id-a.id).slice(0,10);
    return JSON.stringify({messages:combined, unreadCount:inboxes.reduce((n,b)=>n+b.unreadCount,0),
        inboxes:inboxes,status:'ready',detail:''});
}
