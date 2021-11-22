import { useState } from 'react'
import Modal from './Modal';
import Backdrop from './Backdrop';

function Todo() {
    const [modalIsOpen, setModalIsOpen] = useState(false);

    function deletHandler() {
        setModalIsOpen(true);
    }

    function closeModalHandler() {
        setModalIsOpen(false);
    }


    return (
        <div className='card'>
            <h2>TITLE</h2>
            <div className='actions'>
                <button className='btn' onClick={deletHandler}>Delete</button>
            </div>
            {modalIsOpen && <Modal onCancel={closeModalHandler} onConfirm={closeModalHandler} />}
            {modalIsOpen && <Backdrop onCancel={closeModalHandler} />}
        </div>);
}

export default Todo;