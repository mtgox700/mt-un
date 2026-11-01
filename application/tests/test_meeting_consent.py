import unittest
from uuid import uuid4
from uniion.adapters.business_records import dispatch
from uniion.core.contracts import Denied

class MeetingConsentDispatchTests(unittest.TestCase):
    def setUp(self):
        self.calls=[]
        class API:
            def request(_,path,token,payload):
                self.calls.append((path,token,payload));return {'current':False}
        self.api=API()
        self.data={'organization_id':str(uuid4()),'module':'reunions','action':'consent_get','payload':{'id':str(uuid4())}}

    def test_forwards_user_authority_and_exact_payload(self):
        self.assertEqual(dispatch(self.api,'user-token',self.data),{'current':False})
        self.assertEqual(self.calls,[('/rest/v1/rpc/uniion_meeting_consent','user-token',{'p_org':self.data['organization_id'],'p_action':'get','p_payload':self.data['payload']})])

    def test_refuses_other_module_and_injected_authority(self):
        for change in ({'module':'documents'},{'actor':str(uuid4())},{'payload':[]},{'module':'communication'}):
            with self.subTest(change=change),self.assertRaises(Denied):
                dispatch(self.api,'user-token',{**self.data,**change})
        self.assertEqual(self.calls,[])

    def test_withdrawal_forwarded_without_truthiness_conversion(self):
        payload={'id':str(uuid4()),'version':2,'meetingVersion':3,'accepted':False}
        dispatch(self.api,'user-token',{**self.data,'action':'consent_set','payload':payload})
        self.assertEqual(self.calls[0][2]['p_payload'],payload)
        self.assertEqual(self.calls[0][2]['p_action'],'set')
